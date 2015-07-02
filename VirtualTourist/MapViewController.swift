//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import CoreData

class MapViewController: UIViewController, CLLocationManagerDelegate,  NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet var longPress: UILongPressGestureRecognizer!
    
    let regionRadius: CLLocationDistance = 4000000
    
    var locationManager = CLLocationManager()
    var coordinates: CLLocationCoordinate2D?
    var placemark: CLPlacemark!
    
    var alertMessage: String?
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "longitude", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        println("View did load.")
        
        // Start the fetched results controller
        var error: NSError?
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        
        fetchedResultsController.delegate = self
        
        mapView.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        mapView.addGestureRecognizer(longPress)
        
        mapView.addAnnotations(fetchedResultsController.fetchedObjects)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        println("View will appear.")
        self.navigationController?.navigationBarHidden = true
        
        locationManager.startUpdatingLocation()
        //deleteAllPins()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        checkLocationAuthorizationStatus()
    }
    
    override func viewWillDisappear(animated: Bool) {
        locationManager.stopUpdatingLocation()
        
        super.viewWillDisappear(animated)
        //deleteAllPins()
        println("View will disappear")
        // Ensure the coordinates of any dragged pins are updated.
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    @IBAction func longPressed(sender: AnyObject) {
        if longPress.state == .Began {
            println("Long Press Began")
            let point: CGPoint = longPress.locationInView(mapView)
            let fingerLocation: CLLocationCoordinate2D = mapView.convertPoint(point, toCoordinateFromView: mapView)
            println("Finger lat: \(fingerLocation.latitude)")
            println("Finger lon: \(fingerLocation.longitude)")
            
            let pinLocation = CLLocation(latitude: fingerLocation.latitude, longitude: fingerLocation.longitude)
            
            CLGeocoder().reverseGeocodeLocation(pinLocation, completionHandler: {(placemarks, error) -> Void in
                
                if (error != nil) {
                    self.alertMessage = "Reverse geocoder failed with error: " + error.localizedDescription
                    println("\(self.alertMessage)")
                    
                    self.alertUser()
                    
                    return
                }
                
                if placemarks.count > 0 {
                    // maybe don't need this
                    self.locationManager.stopUpdatingLocation()
                    
                    let place = placemarks[0] as! CLPlacemark
                    let placeText = "\(place.locality), \(place.administrativeArea)  \(place.country)"
                    println("\(placeText)")
                    
                    let dictionary: [String : AnyObject] = [
                        Pin.Keys.Title : "\(place.administrativeArea)",
                        Pin.Keys.Address : "\(placeText)",
                        Pin.Keys.Latitude : fingerLocation.latitude,
                        Pin.Keys.Longitude : fingerLocation.longitude
                    ]
                    
                    let newPin = Pin(dictionary: dictionary, context: self.sharedContext)
                    CoreDataStackManager.sharedInstance().saveContext()
                    self.mapView.addAnnotation(newPin)
                }
            })
        } else if longPress.state == .Ended {
            println("Long Press Ended")
        }
    }
    
    // maybe don't need this
    func updateAnnotations() {
        
        println("Updating annotations")
        if let annotations = mapView.annotations {
            
            mapView.removeAnnotations(fetchedResultsController.fetchedObjects)
            
            mapView.addAnnotations(fetchedResultsController.fetchedObjects)
            
        }
    }
    
    func deletePin(pin: Pin) {
        println("Deleting a pin")
        
        sharedContext.deleteObject(pin)
        var error: NSError? = nil
        
        if !sharedContext.save(&error) {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
    }
    
    func deleteAllPins() {
        println("Deleting pins")
        let fetched = fetchedResultsController.fetchedObjects
        
        fetched?.map() {
            self.sharedContext.deleteObject($0 as! NSManagedObject)
        }
        
        var error: NSError? = nil
       
        if !sharedContext.save(&error) {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
    }
    
    func centerMapOnLocation(location: CLLocation) {
        println("Centering Map.")
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func checkLocationAuthorizationStatus() {
        if CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        
        CLGeocoder().reverseGeocodeLocation(manager.location, completionHandler: { (placemarks, error) -> Void in
            if (error != nil) {
                self.alertMessage = "Reverse geocoder failed with error: " + error.localizedDescription
                self.alertUser()
                
                return
            }
            
            if placemarks.count > 0 {
                self.placemark = placemarks[0] as! CLPlacemark
                self.locationManager.stopUpdatingLocation()
                println(self.placemark.locality)
                println(self.placemark.postalCode)
                println(self.placemark.administrativeArea)
                println(self.placemark.country)
                if let place = self.placemark {
                    let placeText = "\(place.locality), \(place.administrativeArea)  \(place.country)"
                    println("\(placeText)")
                }
            }
        })
    }
    
    func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        self.mapView.showsUserLocation = (status == .AuthorizedAlways)
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        
        var errorString = "Error while updating location " + error.localizedDescription
        self.alertMessage = errorString
        self.alertUser()
    }
    
    func alertUser() {
        dispatch_async(dispatch_get_main_queue(), {
            let alertController = UIAlertController(title: "Problem", message: self.alertMessage, preferredStyle: .Alert)
            //alertController.title = "Problem"
            if let message = self.alertMessage {
                alertController.message = message
            }
            
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) -> Void in
                //self.dismissViewControllerAnimated(true, completion: nil)
            }
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
}
