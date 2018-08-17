//
//  CompressSensing.swift
//  gpsData
//
//  Created by Taimir Aguacil on 17.08.18.
//  Copyright © 2018 Taimir Aguacil. All rights reserved.
//

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

class CompressSensing {
    
    //MARK: Properties
    var weights: Matrix<Float>!
    var totalNumberOfSamples : Int
    var latArray_org: [Double]
    var lonArray_org : [Double]
    var latValArray : ValueArray<Double>
    var lonValArray : ValueArray<Double>
    
    let numberOfSamples : Int
    let ratio = 0.1
    
    //Mark: Initializer
    init?(locationVector: [CLLocation]) {
        
        self.latArray_org = []
        self.lonArray_org = []
        
        
        // Extract the coordinates from the location vector if it exists
        guard !locationVector.isEmpty else {
            os_log("No data", log: OSLog.default, type: .debug)
            return nil
        }
        
        self.totalNumberOfSamples = locationVector.count
        self.numberOfSamples = Int(floor(Double(totalNumberOfSamples)*ratio))
        self.latValArray = ValueArray<Double> (capacity: numberOfSamples)
        self.lonValArray = ValueArray<Double> (capacity: numberOfSamples)
        
        for item in locationVector {
            self.latArray_org.append(item.coordinate.latitude)
            self.lonArray_org.append(item.coordinate.longitude)
        }
        
    }
    
    //MARK : RandomSampling and conversion to 2 Upsurge vectors
    func randomSampling() {
        let indices = Array(0...totalNumberOfSamples-1)
        
        var downSampledIndices = indices[randomPick: numberOfSamples]
        downSampledIndices  = downSampledIndices.sorted()
        
        // Put indices element in upsurge vectors
        for item in downSampledIndices {
            latValArray.append(latValArray[item])
            lonValArray.append(lonValArray[item])
        }
    }
    
    
}
