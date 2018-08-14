//
//  RouteViewController.swift
//  gpsData
//
//  Created by Taimir Aguacil on 11.08.18.
//  Copyright © 2018 Taimir Aguacil. All rights reserved.
//

import UIKit
import MapKit
import os.log

class RouteViewController: UIViewController, MKMapViewDelegate, LocationTableViewDelegate {

    //MARK: Properties
    @IBOutlet weak var mapView: MKMapView!
    var locationVector : [CLLocation]?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        if let locationVector = locationVector
        {
            //locationTableViewController.delegate = self
            if locationVector.isEmpty {
                os_log("No data to display, removing pins", log: OSLog.default, type: .debug)
            } else {
                zoomToRegion(initialLocation: locationVector.first!)
                let annotations = getMapAnnotations(locationVector: locationVector)
                // Add mappoints to Map
                mapView.showAnnotations(annotations, animated: true)
                // Connect all the mappoints using Poly line.
                var points = [CLLocationCoordinate2D]()
                for annotation in annotations {
                    points.append(annotation.coordinate)
                }
                let polyline = MKPolyline(coordinates: points, count: points.count)
                mapView.add(polyline)
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
     // MARK: - Navigation
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
    */
    
    //MARK: LocationTabViewDelegate
    func updateLocation(_ locationTableViewController : LocationTableViewController, didGetNewLocation newLocation: CLLocation) {
        var annotations = [MKAnnotation]()
        let annotation = MKPointAnnotation()
        locationVector?.append(newLocation)
        annotation.coordinate = newLocation.coordinate
        annotations.append(annotation)
        mapView.addAnnotations(annotations)
        
        var points = [CLLocationCoordinate2D]()
        let beforeLastElem =  locationVector![(locationVector?.count)!-2]
        points.append(beforeLastElem.coordinate)
            points.append(newLocation.coordinate)
        let polyline = MKPolyline(coordinates: points, count: points.count)
        mapView.add(polyline)
    }
    
    //MARK:- MapViewDelegate methods
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer{
            let polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor.blue
            polylineRenderer.lineWidth = 4.0
            return polylineRenderer
    }

    //MARK:- Zoom to region
    func zoomToRegion(initialLocation : CLLocation ) {
        let region = MKCoordinateRegion(center: initialLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.setRegion(region, animated: true)
    }
    
    //MARK:- Annotations
    func getMapAnnotations(locationVector : [CLLocation]) -> [MKAnnotation] {
        var annotations = [MKAnnotation]()
        
        //iterate and create annotations
            for item in locationVector {
                let myAnnotation : MKPointAnnotation = MKPointAnnotation()
                myAnnotation.coordinate = item.coordinate
                myAnnotation.title = "\(item.timestamp)"
                annotations.append(myAnnotation)
        }
        return annotations
    }
    
    //MARK: Private Properties
    
}
