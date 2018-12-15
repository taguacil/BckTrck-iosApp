//
//  LocationTableViewController.swift
//  gpsData
//
//  Created by Taimir Aguacil on 10.08.18.
//  Copyright © 2018 Taimir Aguacil. All rights reserved.
//

import UIKit
import CoreLocation
import os.log

//MARK: Protocol
protocol LocationTableViewDelegate : class {
    func updateLocation(_ locationTableViewController : LocationTableViewController, didGetNewLocation newLocation: CLLocation)
}

class LocationTableViewController: UITableViewController, CLLocationManagerDelegate {
    
    // MARK: Properties
    @IBOutlet weak var navigationBar: UINavigationItem!
    let locationManager = CLLocationManager()
    var runningCode = false
    var iteration = 0
    var locationVector = [CLLocation] ()
    var logString = String()
    var playBtn = UIBarButtonItem()
    var stopBtn = UIBarButtonItem()
    
    weak var delegate: LocationTableViewDelegate?
    
    //MARK: Table controller functions
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UIBarButton
        self.playBtn = UIBarButtonItem(barButtonSystemItem: .play , target: self, action: #selector(flipBtnAction(sender:)))
        self.stopBtn = UIBarButtonItem(barButtonSystemItem: .stop , target: self, action: #selector(flipBtnAction(sender:)))
        self.navigationItem.rightBarButtonItem = playBtn
        
        // Handle the location field's user input through delegate callbacks
        locationManager.delegate = self
        enableBasicLocationServices()
        
        // Load any saved locationData.
        if let savedLocation = loadLocation() {
            locationVector += savedLocation
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return locationVector.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "LocationTableViewCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? LocationTableViewCell else {
            fatalError("The dequeued cell is not an instance of LocationTableViewCell.")
        }
        
        // Configure the cell...
        cell.acqVal.text = "\(indexPath.row), \(locationVector[indexPath.row].timestamp)"
        
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            locationVector.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            saveLocation()
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    /*
     // Override to support rearranging the table view.
     override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case "ShowDetail":
            guard let locationDetailViewController = segue.destination as? DetailsViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedLocationDataCell = sender as? LocationTableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = tableView.indexPath(for: selectedLocationDataCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            
            let selectedLocation = locationVector[indexPath.row]
            locationDetailViewController.locationData = selectedLocation
            
        case "ShowRoute":
            guard let routeViewController = segue.destination as? RouteViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            routeViewController.locationVector = locationVector
            self.delegate = routeViewController
            
        case "ShowSettings":
            guard let settingsController = segue.destination as? SettingsController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            settingsController.locationVector=locationVector
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
        
    }
    
    //MARK: CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation:CLLocation = locations[0] as CLLocation
        
        iteration += 1
        
        logString = "DEBUG: acquisition \(iteration)"
        print(logString)
        
        print("user latitude = \(userLocation.coordinate.latitude)")
        print("user longitude = \(userLocation.coordinate.longitude)")
        print(" \(userLocation.timestamp)")
        // Add a new location object.
        let newIndexPath = IndexPath(row: locationVector.count, section: 0)
        
        locationVector.append(userLocation)
        delegate?.updateLocation(self, didGetNewLocation: userLocation)
        tableView.insertRows(at: [newIndexPath], with: .automatic)
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .restricted, .denied:
            os_log("Location services not enabled", log: OSLog.default, type: .debug)
            break
            
        case .notDetermined, .authorizedWhenInUse, .authorizedAlways:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        print("Error \(error)")
    }
    
    //MARK: Actions
    @objc func flipBtnAction(sender: UIBarButtonItem)
    {
        if runningCode {
            runningCode = false
            self.navigationItem.rightBarButtonItem = playBtn
            locationManager.stopUpdatingLocation()
            saveLocation()
        }
        else {
            runningCode = true
            self.navigationItem.rightBarButtonItem = stopBtn
            startLocationAcquisition()
        }
        
    }
    @IBAction func clearButton(_ sender: UIBarButtonItem) {
        locationVector.removeAll()
        stopAcquisition()
        tableView.reloadData()
    }
    
    @IBAction func shareButton(_ sender: UIBarButtonItem) {
        stopAcquisition()
        
        let fileName = "gpsLocation_\(String(describing: locationVector.first?.timestamp)).csv "
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        var csvText = "Date,Latitude,Longitude,Altitude,Speed,Course,Vertical accuracy, horizontal accuracy\n"
        
        let count = locationVector.count
        
        if count > 0 {
            
            for item in locationVector {
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = DateFormatter.Style.short
                dateFormatter.timeStyle = .medium
                let convertedDate = dateFormatter.string(from: item.timestamp)
                
                
                let newLine = "\(convertedDate),\(item.coordinate.latitude),\(item.coordinate.longitude),\(item.altitude),\(item.speed),\(item.course),\(item.verticalAccuracy),\(item.horizontalAccuracy)\n"
                
                csvText.append(contentsOf: newLine)
            }
            
            do {
                try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
                
                let vc = UIActivityViewController(activityItems: [path!], applicationActivities: [])
                vc.excludedActivityTypes = [
                    UIActivityType.assignToContact,
                    UIActivityType.saveToCameraRoll,
                    UIActivityType.postToFlickr,
                    UIActivityType.postToVimeo,
                    UIActivityType.postToTencentWeibo,
                    UIActivityType.postToTwitter,
                    UIActivityType.postToFacebook,
                    UIActivityType.openInIBooks
                ]
                present(vc, animated: true, completion: nil)
                
            } catch {
                os_log("Failed to create file", log: OSLog.default, type: .error)
                print("\(error)")
            }
            
        } else {
            os_log("There is no data to export", log: OSLog.default, type: .debug)
        }
    }
    
    @IBAction func computeButton(_ sender: UIBarButtonItem) {
        stopAcquisition()
    }
    
    //MARK: Private Properties
    private func stopAcquisition (){
        // Stop acquisition
        if runningCode {
            runningCode = false
            self.navigationItem.rightBarButtonItem = playBtn
            locationManager.stopUpdatingLocation()
        }
        saveLocation()
    }
    
    private func enableBasicLocationServices() {
        
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            // Request when-in-use authorization initially
            locationManager.requestWhenInUseAuthorization()
            break
            
        case .restricted, .denied:
            // Disable location features
            os_log("Location services not enabled", log: OSLog.default, type: .debug)
            break
            
        case .authorizedWhenInUse:
            // Enable location features
            os_log("Location services only enabled when in use", log: OSLog.default, type: .debug)
            locationManager.requestAlwaysAuthorization()
            break
            
        case .authorizedAlways:
            // Enable location features
            os_log("Location services always enabled", log: OSLog.default, type: .debug)
            break
        }
    }
    
    private func startLocationAcquisition() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        if CLLocationManager.locationServicesEnabled() {
            //locationManager.requestLocation()
            
            locationManager.startUpdatingLocation()
            //locationManager.startUpdatingHeading()
        } else {
            // Update your app’s UI to show that the location is unavailable.
        }
    }
    
    private func saveLocation() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(locationVector, toFile: CompressSensing.ArchiveURL.path)
        
        if isSuccessfulSave {
            os_log("Location successfully saved.", log: OSLog.default, type: .debug)
        } else {
            os_log("Failed to save location...", log: OSLog.default, type: .error)
        }
    }
    
    private func loadLocation() -> [CLLocation]? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: CompressSensing.ArchiveURL.path) as? [CLLocation]
    }
}
