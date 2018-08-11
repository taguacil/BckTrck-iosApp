//
//  DetailstViewController.swift
//  gpsData
//
//  Created by Taimir Aguacil on 10.08.18.
//  Copyright © 2018 Taimir Aguacil. All rights reserved.
//

import UIKit
import CoreLocation
import os.log

class DetailsViewController: UIViewController {
    
    //MARK: Properties
    @IBOutlet weak var latLabel: UILabel!
    @IBOutlet weak var lonLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var courseLabel: UILabel!
    @IBOutlet weak var vertAccLabel: UILabel!
    @IBOutlet weak var horizAccLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    var locationData: CLLocation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let locationData = locationData {
            latLabel.text = "\(locationData.coordinate.latitude)"
            lonLabel.text = "\(locationData.coordinate.longitude)"
            altitudeLabel.text = "\(locationData.altitude)"
            speedLabel.text = "\(locationData.speed)"
            courseLabel.text = "\(locationData.course)"
            vertAccLabel.text = "\(locationData.verticalAccuracy)"
            horizAccLabel.text = "\(locationData.horizontalAccuracy)"
            dateLabel.text = "\(locationData.timestamp)"
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

