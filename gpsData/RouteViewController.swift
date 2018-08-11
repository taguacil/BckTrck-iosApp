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

class RouteViewController: UIViewController, MKMapViewDelegate {
    
    //MARK: Properties
    @IBOutlet weak var mapView: MKMapView!
    var locationVector : [CLLocation]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        
        if let locationVector = locationVector {
            if locationVector.isEmpty {
                os_log("No data to display", log: OSLog.default, type: .debug)
            } else {
                zoomToRegion(initialLocation: locationVector.first!)
                let annotations = getMapAnnotations()
                // Add mappoints to Map
                mapView.addAnnotations(annotations)
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
    func getMapAnnotations() -> [MKAnnotation] {
        var annotations = [MKAnnotation]()
        
        //iterate and create annotations
        if let items = locationVector {
            for item in items {
                let myAnnotation : MKPointAnnotation = MKPointAnnotation()
                myAnnotation.coordinate = item.coordinate
                myAnnotation.title = "\(item.timestamp)"
                annotations.append(myAnnotation)
            }
        }
        return annotations
    }
    
}
