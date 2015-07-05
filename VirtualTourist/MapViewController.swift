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
    
    var zoomDictionary = [String : AnyObject]()
    var locationManager = CLLocationManager()
    var coordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 39.50, longitude: -98.35) // Set default to center of US.
    var regionSpan: MKCoordinateSpan? = MKCoordinateSpan(latitudeDelta: 4000, longitudeDelta: 4000)
    var placemark: CLPlacemark!
    
    var alertMessage: String?
    
    
    var region: MKCoordinateRegion {
        return MKCoordinateRegionMake(coordinate!, regionSpan!)
    }
    
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        return url.URLByAppendingPathComponent("zoomDictionary").path!
    }

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
    
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
        static let LatitudeDelta = "latitudeDelta"
        static let LongitudeDelta = "longitudeDelta"
    }
    
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
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "saveRegion", name: "saveData", object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        println("View will appear.")
        self.navigationController?.navigationBarHidden = true

        //deleteAllPins()
        //centerMapOnLocation()
        
        if let dictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            zoomDictionary = dictionary
            setRegion()
        } else {
            locationManager.startUpdatingLocation()
            locationManager.pausesLocationUpdatesAutomatically = true
        }
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
        saveRegion()
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
    
    // Set the Region to saved zoom level
    func setRegion() {
        // upadate this with an UnarchivedKey
        if let lat = zoomDictionary[Keys.Latitude] as? CLLocationDegrees {
            if let lon = zoomDictionary[Keys.Longitude] as? CLLocationDegrees {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        
        if let latDel = zoomDictionary[Keys.LatitudeDelta] as? CLLocationDegrees {
            if let lonDel = zoomDictionary[Keys.LongitudeDelta] as? CLLocationDegrees {
                regionSpan = MKCoordinateSpan(latitudeDelta: latDel, longitudeDelta: lonDel)
            }
        }
        
        mapView.setRegion(region, animated: true)
    }
    
    
    // Save the region to file
    func saveRegion() {
        println("Saving region and zoom.")
        println("First saving Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
        coordinate = mapView.region.center
        regionSpan = mapView.region.span
        println("Second saving Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
        if let coord = coordinate {
            zoomDictionary[Keys.Latitude] = coord.latitude
            zoomDictionary[Keys.Longitude] = coord.longitude
            zoomDictionary[Keys.LatitudeDelta] = regionSpan?.latitudeDelta
            zoomDictionary[Keys.LongitudeDelta] = regionSpan?.longitudeDelta
            
            // Save the dictionary
            NSKeyedArchiver.archiveRootObject(zoomDictionary, toFile: filePath)
        }
    }
    
    // Maybe won't use this
    func centerMapOnLocation() {
        println("Centering Map.")
        
        mapView.setRegion(region, animated: true)
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
    
    func checkLocationAuthorizationStatus() {
        if CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func locationManager(manager: CLLocationManager!, didUpdateToLocation newLocation: CLLocation!, fromLocation oldLocation: CLLocation!) {
        
        // Reset mapView.
        coordinate = newLocation.coordinate
        mapView.setRegion(region, animated: true)
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
