//
//  CompressSensing.swift
//  gpsData
//
//  Created by Taimir Aguacil on 17.08.18.
//  Copyright © 2018 Taimir Aguacil. All rights reserved.
//

/*
 Init with location vector
 Downsample by random sampling
 Transform to ValueArray
 Normalize
 Compute DCT of eye(N) and pick on N*ratio or comupte directly
 Perform Lasso
 Get the weights
 Perform IDCT
 Compute MSE
 Revert the normalization
 Send back the reconstructed signal
 Plot both paths and display accuracy in %
 */

import Accelerate
import Upsurge
import MachineLearningKit
import CoreLocation
import os.log

extension Array {
    /// Picks `n` random elements (partial Fisher-Yates shuffle approach)
    subscript (randomPick n: Int) -> [Element] {
        var copy = self
        for i in stride(from: count - 1, to: count - n - 1, by: -1) {
            copy.swapAt(i, Int(arc4random_uniform(UInt32(i + 1))))
        }
        return Array(copy.suffix(n))
    }
}

class CompressSensing : NSObject, NSCoding {
    
    //MARK: Properties
    let locationVector : [CLLocation]?
    var weights_lat: Matrix<Float>!
    var weights_lon: Matrix<Float>!
    var totalNumberOfSamples : Int
    var latArray_org: [Float]
    var lonArray_org : [Float]
    var lat_est : [Float]
    var lon_est : [Float]
    var latValArray : Array<Float>
    var lonValArray : Array<Float>
    var meanLat = Float(0)
    var meanLon = Float(0)
    var stdLat  = Float(0)
    var stdLon  = Float(0)
    
    lazy var dctSetupForward: vDSP_DFT_Setup = {
        guard let setup = vDSP_DCT_CreateSetup(
            nil,
            vDSP_Length(totalNumberOfSamples),
            .II)else {
                fatalError("can't create forward vDSP_DFT_Setup")
        }
        return setup
    }()
    
    lazy var dctSetupInverse: vDSP_DFT_Setup = {
        guard let setup = vDSP_DCT_CreateSetup(
            nil,
            vDSP_Length(totalNumberOfSamples),
            .III) else {
                fatalError("can't create inverse vDSP_DFT_Setup")
        }
        
        return setup
    }()
    
    let numberOfSamples : Int
    let ratio = 1.0 // with .x because double
    let l1_penalty = Float(0.01) // learning rate
    let tolerance = Float(0.0001)
    let iteration = 500
    let lassModel = LassoRegression()
    
    //MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("locationVector")
    
    //MARK: Types
    struct PropertyKey {
        static let locationVector = "locationVector"
    }
    
    //Mark: Initializer
    init?(inputLocationVector: [CLLocation]) {
        
        self.latArray_org = []
        self.lonArray_org = []
        self.lat_est = []
        self.lon_est = []
        self.latValArray = []
        self.lonValArray = []
        
        // Extract the coordinates from the location vector if it exists
        guard !inputLocationVector.isEmpty else {
            os_log("No data", log: OSLog.default, type: .debug)
            return nil
        }
        self.locationVector = inputLocationVector
        self.totalNumberOfSamples = inputLocationVector.count
        self.numberOfSamples = Int(floor(Double(totalNumberOfSamples)*ratio))
        //self.latValArray = Array<Float> (repeating:0, count: Int(numberOfSamples))
        //self.lonValArray = Array<Float> (repeating:0, count: Int(numberOfSamples))
        
        for item in inputLocationVector {
            self.latArray_org.append(Float(item.coordinate.latitude))
            self.lonArray_org.append(Float(item.coordinate.longitude))
        }
        
    }
    
    //MARK: DeInit
    deinit {
        vDSP_DFT_DestroySetup(dctSetupForward)
        vDSP_DFT_DestroySetup(dctSetupInverse)
    }
    
    //MARK: NSCoding
    func encode(with aCoder: NSCoder) {
        aCoder.encode(locationVector, forKey: PropertyKey.locationVector)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let locationVector = aDecoder.decodeObject(forKey: PropertyKey.locationVector) as? [CLLocation] else {
            os_log("Unable to decode the locationVector for a CompressSensing object.", log: OSLog.default, type: .debug)
            return nil
        }
        // Must call designated initializer.
        self.init(inputLocationVector: locationVector)
    }
    
    //MARK: RandomSampling and conversion to 2 Upsurge vectors
    private func randomSampling() -> [Int]{
        os_log("Random sampling", log: OSLog.default, type: .debug)
        let indices = Array(0...totalNumberOfSamples-1)
        
        var downSampledIndices = indices[randomPick: numberOfSamples]
        downSampledIndices  = downSampledIndices.sorted()
        
        // Put indices element in upsurge vectors
        for item in downSampledIndices {
            latValArray.append(latArray_org[item])
            lonValArray.append(lonArray_org[item])
        }
        meanLat = mean(latValArray)
        meanLon = mean(lonValArray)
        stdLat  = std(latValArray)
        stdLon  = std(lonValArray)
        latValArray = Array((latValArray-meanLat)/(stdLat))
        lonValArray = Array((lonValArray-meanLon)/(stdLon))
        return downSampledIndices
    }
    
    //MARK: DCT operations
    private func forwardDCT<M: LinearType>(_ input: M) -> [Float] where M.Element == Float {
        os_log("Forward DCT", log: OSLog.default, type: .debug)
        var results = Array<Float>(repeating:0, count: Int(totalNumberOfSamples))
        let realVector = ValueArray<Float>(input)
        vDSP_DCT_Execute(dctSetupForward,
                         realVector.pointer,
                         &results)
        
        return results
    }
    
    /* Performs a real to read forward IDCT  */
    private func inverseDCT<M: LinearType>(_ input: M) -> [Float] where M.Element == Float {
        os_log("Inverse DCT", log: OSLog.default, type: .debug)
        var results = Array<Float>(repeating:0, count: Int(totalNumberOfSamples))
        let realVector = ValueArray<Float>(input)
        vDSP_DCT_Execute(dctSetupInverse,
                         realVector.pointer,
                         &results)
        return results
    }
    
    //MARK: DCT of Identity
    private func eyeDCT(downSampledIndices: [Int]) -> [Array<Float>] {
        os_log("Identiy DCT function", log: OSLog.default, type: .debug)
        var pulseVector = Array<Float>(repeating: 0.0, count: totalNumberOfSamples)
        let dctVec = ValueArray<Float>(capacity: numberOfSamples*totalNumberOfSamples)
        var dctMat = Matrix<Float>(rows: numberOfSamples, columns: totalNumberOfSamples)
        var dctArrayMat = Array<Array<Float>>() // TODO not efficient
        for item in downSampledIndices {
            pulseVector[item] = 1.0
            let dctVector = forwardDCT(pulseVector)
            pulseVector[item] = 0.0
            dctVec.append(contentsOf: dctVector)
        }
        dctMat = dctVec.toMatrix(rows: numberOfSamples, columns: totalNumberOfSamples)
        print(dctVec.description)
        print(dctMat.description)
        
        var temp = Array<Float>()
        for col in 0..<dctMat.columns
        {
            for row in 0..<dctMat.rows
            {
                temp.append(dctMat[row, col])
            }
            dctArrayMat.append(temp)
            temp.removeAll(keepingCapacity: true)
        }
        return dctArrayMat
    }
    
    //MARK: LASSO regression
    private func lassoReg (dctMat : [Array<Float>]){
        os_log("Lasso regression function", log: OSLog.default, type: .debug)
        // Set Initial Weights
        let initial_weights_lat = Matrix<Float>(rows: totalNumberOfSamples+1, columns: 1, repeatedValue: 0)
        let initial_weights_lon = Matrix<Float>(rows: totalNumberOfSamples+1, columns: 1, repeatedValue: 0)
        weights_lat = try! lassModel.train(dctMat, output: latValArray, initialWeights: initial_weights_lat, l1Penalty: l1_penalty, tolerance: tolerance, iteration : iteration)
        print(dctMat.description)
        print(latValArray.description)
        print(weights_lat.description)
        print(weights_lat.column(1).description)
        weights_lon = try! lassModel.train(dctMat, output: latValArray, initialWeights: initial_weights_lon, l1Penalty: l1_penalty, tolerance: tolerance, iteration : iteration)
    }
    
    /* Performs IDCT of weights */
    private func IDCT_weights() {
        os_log("IDCT of weights", log: OSLog.default, type: .debug)
            lat_est = inverseDCT(weights_lat.column(1))
            lon_est = inverseDCT(weights_lon.column(1))
        lat_est = Array((lat_est*stdLat)+meanLat)
        lon_est = Array((lon_est*stdLon)+meanLon)
    }
    
    //MARK: Complete computation
    func compute() -> [CLLocationCoordinate2D] {
        let downSampledIndices = randomSampling()
        let dctMat = eyeDCT(downSampledIndices: downSampledIndices)
        lassoReg(dctMat: dctMat)
        IDCT_weights()
        var est_coord = [CLLocationCoordinate2D]()
        for item in 0..<lat_est.count{
            est_coord.append(CLLocationCoordinate2DMake(Double(lat_est[item]), Double(lon_est[item])))
        }
        return est_coord
    }
    
}
