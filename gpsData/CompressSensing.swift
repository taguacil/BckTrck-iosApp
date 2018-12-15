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
    var iteration : Int?
    var ratio : Double?
    var l1_penalty : Float? // learning rate
    var blockLength : Int?
    
    var weights_lat: Matrix<Float>!
    var weights_lon: Matrix<Float>!
    
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
            vDSP_Length(blockLength!),
            .II)else {
                fatalError("can't create forward vDSP_DFT_Setup")
        }
        return setup
    }()
    
    lazy var dctSetupInverse: vDSP_DFT_Setup = {
        guard let setup = vDSP_DCT_CreateSetup(
            nil,
            vDSP_Length(blockLength!),
            .III) else {
                fatalError("can't create inverse vDSP_DFT_Setup")
        }
        
        return setup
    }()
    
    var blockSamples : Int
    let tolerance = Float(0.0001)
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
        
        self.blockSamples = 0
        
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
        //self.latValArray = Array<Float> (repeating:0, count: Int(blockSamples))
        //self.lonValArray = Array<Float> (repeating:0, count: Int(blockSamples))
        
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
        let indices = Array(0...blockLength!-1)
        
        var downSampledIndices = indices[randomPick: blockSamples]
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
        var results = Array<Float>(repeating:0, count: Int(blockLength!))
        let realVector = ValueArray<Float>(input)
        vDSP_DCT_Execute(dctSetupForward,
                         realVector.pointer,
                         &results)
        return results
    }
    
    /* Performs a real to read forward IDCT  */
    private func inverseDCT<M: LinearType>(_ input: M) -> [Float] where M.Element == Float {
        os_log("Inverse DCT", log: OSLog.default, type: .debug)
        var results = Array<Float>(repeating:0, count: Int(blockLength!))
        let realVector = ValueArray<Float>(input)
        vDSP_DCT_Execute(dctSetupInverse,
                         realVector.pointer,
                         &results)
        return results
    }
    
    //MARK: DCT of Identity
    private func eyeDCT(downSampledIndices: [Int]) -> [Array<Float>] {
        os_log("Identiy DCT function", log: OSLog.default, type: .debug)
        var pulseVector = Array<Float>(repeating: 0.0, count: blockLength!)
        let dctVec = ValueArray<Float>(capacity: blockSamples*blockLength!)
        var dctMat = Matrix<Float>(rows: blockSamples, columns: blockLength!)
        var dctArrayMat = Array<Array<Float>>() // TODO not efficient
        for item in downSampledIndices {
            pulseVector[item] = 1.0
            let dctVector = forwardDCT(pulseVector)
            pulseVector[item] = 0.0
            dctVec.append(contentsOf: dctVector)
        }
        dctMat = dctVec.toMatrix(rows: blockSamples, columns: blockLength!)
        
        /* print debugging
         print(dctVec.description)
         print(dctMat.description)
         */
        
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
        let initial_weights_lat = Matrix<Float>(rows: blockLength!+1, columns: 1, repeatedValue: 0)
        let initial_weights_lon = Matrix<Float>(rows: blockLength!+1, columns: 1, repeatedValue: 0)
        weights_lat = try! lassModel.train(dctMat, output: latValArray, initialWeights: initial_weights_lat, l1Penalty: l1_penalty!, tolerance: tolerance, iteration : iteration!)
        
        /* print debugging
         print(dctMat.description)
         print(latValArray.description)
         print(weights_lat.description)
         print(weights_lat.column(1).description)
         */
        
        weights_lon = try! lassModel.train(dctMat, output: lonValArray, initialWeights: initial_weights_lon, l1Penalty: l1_penalty!, tolerance: tolerance, iteration : iteration!)
    }
    
    /* Performs IDCT of weights */
    private func IDCT_weights(downSampledIndices: [Int]) {
        os_log("IDCT of weights", log: OSLog.default, type: .debug)
        var lat_cor = inverseDCT(weights_lat.column(1))
        var lon_cor = inverseDCT(weights_lon.column(1))
        lat_cor = Array(lat_cor*(1/Float(sqrt(ratio!*0.5*Double(blockLength!)))))
        lon_cor = Array(lon_cor*(1/Float(sqrt(ratio!*0.5*Double(blockLength!)))))
        
        var vec_lat = Array<Float>()
        var vec_lon = Array<Float>()
        
        for index in 0..<downSampledIndices.count
        {
            vec_lat.append(latValArray[index]-lat_cor[downSampledIndices[index]])
            vec_lon.append(lonValArray[index]-lon_cor[downSampledIndices[index]])
        }
        let delta_lat = mean(vec_lat)
        let delta_lon = mean(vec_lon)
        
        lat_est = Array((lat_cor+delta_lat)*stdLat+meanLat)
        lon_est = Array((lon_cor+delta_lon)*stdLon+meanLon)
    }
    
    /* MSE */
    private func MSE() -> Float {
        let MSE = rmsq((lat_est-latArray_org)+(lon_est-lonArray_org))
        print("Total latlon MSE \(MSE)")
        return MSE
    }
    //MARK: Complete computation for 1 block length
    private func computeBlock() -> ([CLLocationCoordinate2D], Float) {
        let downSampledIndices = randomSampling()
        let dctMat = eyeDCT(downSampledIndices: downSampledIndices)
        lassoReg(dctMat: dctMat)
        IDCT_weights(downSampledIndices: downSampledIndices)
        let MSEblock = MSE()
        var est_coord = [CLLocationCoordinate2D]()
        for item in 0..<lat_est.count{
            est_coord.append(CLLocationCoordinate2DMake(Double(lat_est[item]), Double(lon_est[item])))
        }
        return (est_coord, MSEblock)
    }
    
    // Entire computation for all input vector
    func compute() -> ([CLLocationCoordinate2D],Float) {
        let totalLength = locationVector!.count
        let numberOfBlocks = Int(floor(Double(totalLength / blockLength!)))
        var est_coord = [CLLocationCoordinate2D]()
        var AvgMSE : Float = 0
        
        for i in 0..<numberOfBlocks
        {
            latArray_org.removeAll()
            lonArray_org.removeAll()
            lat_est.removeAll()
            lon_est.removeAll()
            latValArray.removeAll()
            lonValArray.removeAll()
            
            for item in locationVector![i*(blockLength!)...((i+1)*blockLength!)-1] {
                latArray_org.append(Float(item.coordinate.latitude))
                lonArray_org.append(Float(item.coordinate.longitude))
            }
            let (est_coord_block, MSEblock) = computeBlock()
            AvgMSE = AvgMSE + MSEblock
            for item in est_coord_block
            {
                est_coord.append(item)
            }
        }
        return (est_coord, AvgMSE)
    }
    //MARK: Function to set parameters
    func setParam(maxIter:Int, pathLength:Int, samplingRatio:Double, learningRate:Float){
        os_log("Setting algorithm parameters", log: OSLog.default, type: .debug)
        iteration = maxIter
        blockLength = pathLength
        ratio = samplingRatio
        l1_penalty = learningRate
        blockSamples = Int(floor(Double(blockLength!)*ratio!)) // to sample in a block
    }
    
}
