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

// Removed this from list of delegate conformers: CollectionViewControllerDelegate

// Controller of the view of the main map.
class MapViewController: UIViewController, CLLocationManagerDelegate,  NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet var longPress: UILongPressGestureRecognizer!
    
    var zoomDictionary = [String : AnyObject]()
    var locationManager = CLLocationManager()
    var coordinate: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 39.50, longitude: -98.35) // Set default to center of US.
    var regionSpan: MKCoordinateSpan? = MKCoordinateSpan(latitudeDelta: 4000, longitudeDelta: 4000)
    var placemark: CLPlacemark!
    
    var alertMessage: String?
    
    var pins = [Pin]()
    
    // Computed property created from the coordinate and the span.
    var region: MKCoordinateRegion {
        return MKCoordinateRegionMake(coordinate!, regionSpan!)
    }
    
    // Computed property storing the level of map-zoom between appearances.
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first //as NSURL
        return url!.URLByAppendingPathComponent("zoomDictionary").path!
    }

    // Computed property storing the shared context of the Core Data Stack.
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    // Computed property returning the Pin fetch results controller from the shared instance of PinPhotos.
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        return PinPhotos.sharedInstance().pinFetchedResultsController
//        let fetchRequest = NSFetchRequest(entityName: "Pin")
//        
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "longitude", ascending: true)]
//        
//        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
//            managedObjectContext: self.sharedContext,
//            sectionNameKeyPath: nil,
//            cacheName: nil)
//        
//        return fetchedResultsController
    }()
    
    // Useful keys for the Pin dictionary.
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
        static let LatitudeDelta = "latitudeDelta"
        static let LongitudeDelta = "longitudeDelta"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("View did load.")
        
        listFilesFromDocumentsFolder()
        
        // Start the fetched results controller
        var error: NSError?
        do {
            try fetchedResultsController.performFetch()
        } catch let error1 as NSError {
            error = error1
        }
        
        // Check for error.
        if let error = error {
            
            // Use UIAlertController to inform user of issue.
            alertMessage = "Error performing initial fetch: \(error)"
            
            print(alertMessage)
            alertUser()
        }
        
        // Make self the delegate of map view, location manager, and fetched results controller.
        mapView.delegate = self
        locationManager.delegate = self
        fetchedResultsController.delegate = self
        
        // Set tracking accuracy for location manager.
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        
        // Assign array of Pin objects to the fetched results controller array.
        pins = fetchedResultsController.fetchedObjects as! [Pin]
        
        // Add Pin type annotations to the map view.
        mapView.addAnnotations(pins)
        
        // Add a long press gesture recognizer to create new pins.
        mapView.addGestureRecognizer(longPress)
        
        // Add an observer for the zoom settings to the notification center.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "saveRegion", name: "saveData", object: nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        print("View will appear.")
        
        // Hide the navigation bar.
        self.navigationController?.navigationBarHidden = true

        //deleteAllPins()
        //centerMapOnLocation()
        
//        println("Updating annotations")
//        if let annotations = mapView.annotations {
//            
//            mapView.removeAnnotations(fetchedResultsController.fetchedObjects)
//        }
//        
//        CoreDataStackManager.sharedInstance().saveContext()
//
//        var error: NSError? = nil
//        
//        if !sharedContext.save(&error) {
//            alertMessage = "Error performing initial fetch: \(error)"
//            
//            println(alertMessage)
//            alertUser()
//        }
        
        // Update the annotations to reflect Pin changes.
        updateAnnotations()
        
        // Check if there is a stored dictionary of zoom data from previous usage.
        if let dictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            zoomDictionary = dictionary
            setRegion()
        } else {
            
            // Handle location manager settings.
            locationManager.startUpdatingLocation()
            locationManager.pausesLocationUpdatesAutomatically = true
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if location manager has authority to track currnt location.
        checkLocationAuthorizationStatus()
    }
    
    override func viewWillDisappear(animated: Bool) {
        
        // Stop location manager from updating location as segueing.
        locationManager.stopUpdatingLocation()
        
        //deleteAllPins()
        print("View will disappear")
        //mapView.removeAnnotations(fetchedResultsController.fetchedObjects)
        // Ensure the coordinates of any dragged pins are updated.
        // IMPORTANT : maybe won't need dragging
        //CoreDataStackManager.sharedInstance().saveContext()
        //saveRegion()
        
        super.viewWillDisappear(animated)
    }
    
    // Drop a pin where long press was held and create a Pin object.
    @IBAction func longPressed(sender: AnyObject) {
        
        // Check if state is began.
        if longPress.state == .Began {
            print("Long Press Began")
            
            // Create a point from the long press location of the map view.
            let point: CGPoint = longPress.locationInView(mapView)
            
            // Create a coordinate from the point.
            let fingerLocation: CLLocationCoordinate2D = mapView.convertPoint(point, toCoordinateFromView: mapView)
            print("Finger lat: \(fingerLocation.latitude)")
            print("Finger lon: \(fingerLocation.longitude)")
            
            // Create a location for the pin from the latitude and longitude.
            let pinLocation = CLLocation(latitude: fingerLocation.latitude, longitude: fingerLocation.longitude)
            
            // Get string data of that location.
            CLGeocoder().reverseGeocodeLocation(pinLocation, completionHandler: {(placemarks, error) -> Void in
                
                // Check for an error.
                if (error != nil) {
                    
                    // Use UIAlertController to inform user of issue.
                    self.alertMessage = "Reverse geocoder failed with error: " + error!.localizedDescription
                    print("\(self.alertMessage)")
                    
                    self.alertUser()
                    
                    return
                }
                
                // Make sure there is at least one place in the placemarks array.
                //if placemarks!.count > 0 {
                if let place = placemarks!.first {
                    // Stop updating the location manager while accessing this data.
                    self.locationManager.stopUpdatingLocation()
                    
                    // Create a placemark from the first object in the placemarks array.
                    //let place = placemarks[0] //as! CLPlacemark
                    
                    // Create strings showing the amount of data discovered at this location.
                    let locality = place.locality ?? "Unknown"
                    let adminArea = place.administrativeArea ?? "Unknown"
                    let country = place.country ?? "Unknown"
                    
                    // Create a more readable format (like City, State Country) for the Pin.
                    let placeText = "\(locality), \(adminArea)  \(country)"
                    print("\(placeText)")
                    
                    // Create a dictionary of keys and values necessary for creating a Pin object.
                    let dictionary: [String : AnyObject] = [
                        Pin.Keys.Title : "\(place.administrativeArea)",
                        Pin.Keys.Address : "\(placeText)",
                        Pin.Keys.Latitude : fingerLocation.latitude,
                        Pin.Keys.Longitude : fingerLocation.longitude
                    ]
                    
                    // Create a new Pin object with the dictionary and the shared Managed Object Context.
                    let newPin = Pin(dictionary: dictionary, context: self.sharedContext)
                    
                    // Save the data to Core Data.
                    CoreDataStackManager.sharedInstance().saveContext()
                    
                    // Add the newest Pin to the annotations array
                    self.mapView.addAnnotation(newPin)
                }
            })
            
            // Check if state is ended.
        } else if longPress.state == .Ended {
            print("Long Press Ended")
        }
    }
    
    // Set the Region to saved zoom level
    func setRegion() {
        // IMPORTANT: update this with an UnarchivedKey; need I do this?
        
        // Ensure zoom dictionary has a latitude.
        if let lat = zoomDictionary[Keys.Latitude] as? CLLocationDegrees {
            
            // Ensure zoom dictionary has a longitude as well.
            if let lon = zoomDictionary[Keys.Longitude] as? CLLocationDegrees {
                
                // Set coordinate with the latitude and longitude.
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        
        // Ensure zoom dictionary has a latitude reflecting the change.
        if let latDel = zoomDictionary[Keys.LatitudeDelta] as? CLLocationDegrees {
            
            // Ensure zoom dictionary has a longitude reflecting the change as well.
            if let lonDel = zoomDictionary[Keys.LongitudeDelta] as? CLLocationDegrees {
                
                // Set the span of the region with the changes in latitude and longitude.
                regionSpan = MKCoordinateSpan(latitudeDelta: latDel, longitudeDelta: lonDel)
            }
        }
        
        // Set the zoom level to the region property computed with the coordinate and the region span.
        mapView.setRegion(region, animated: true)
    }
    
    
    // Save the region to file
    func saveRegion() {
        print("Saving region and zoom.")
        print("First saving Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
        
        // Set coordinate and region span to the present map view data.
        coordinate = mapView.region.center
        regionSpan = mapView.region.span
        
        print("Second saving Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
        
        // Ensure there is a coordinate.
        if let coord = coordinate {
            
            // Set the zoomDictionary keys to related values.
            zoomDictionary[Keys.Latitude] = coord.latitude
            zoomDictionary[Keys.Longitude] = coord.longitude
            zoomDictionary[Keys.LatitudeDelta] = regionSpan?.latitudeDelta
            zoomDictionary[Keys.LongitudeDelta] = regionSpan?.longitudeDelta
            
            // Save the dictionary
            NSKeyedArchiver.archiveRootObject(zoomDictionary, toFile: filePath)
        }
    }
    
    // Maybe won't use this
//    func centerMapOnLocation() {
//        println("Centering Map.")
//        
//        mapView.setRegion(region, animated: true)
//    }
    
//    func removeAnnotation(collectionViewController: CollectionViewController, withPin pin: Pin?) {
//        if let deadPin = pin {
//            println("Removing a pin")
//            self.mapView.removeAnnotation(pin)
//        }
//    }
    
    // IMPORTANT: this needs to be fixed.
    // Update the annotations to reflect Pin changes.
    func updateAnnotations() {
        print("Updating annotations")
        
        // Ensure there are annotations.
        //if let annotations = mapView.annotations as? [MKAnnotation] {
            
            // Update array of Pin objects to the fetched results controller array.
            pins = fetchedResultsController.fetchedObjects as! [Pin]
            
            // Remove all of the existing Pin annotations.
            mapView.removeAnnotations(pins)
            
            // IMPORTANT: see if we can use this.
            //PinPhotos.sharedInstance().cleanupPins()
            //CoreDataStackManager.sharedInstance().saveContext()
            
            
            // Update array of Pin objects to the fetched results controller array.
            pins = fetchedResultsController.fetchedObjects as! [Pin]
            
            // Add annotations using the data in each Pin in the array.
            mapView.addAnnotations(pins)
        //}
    }
    
    // Check if location manager has authority to track current location.
    func checkLocationAuthorizationStatus() {
        
        // Check if authorized to track.
        if CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse {
            
            // Track current location.
            mapView.showsUserLocation = true
        } else {
            
            // Request authorization to track current location.
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // Handle update to location.
    func locationManager(manager: CLLocationManager, didUpdateToLocation newLocation: CLLocation, fromLocation oldLocation: CLLocation) {
        
        // Reset mapView.
        coordinate = newLocation.coordinate
        mapView.setRegion(region, animated: true)
    }
    
    // Inform stakeholders that location was updated by location manager.
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Get readable strings of location data.
        CLGeocoder().reverseGeocodeLocation(manager.location!, completionHandler: { (placemarks, error) -> Void in
            
            // Check for error
            if (error != nil) {
                
                // Use UIAlertController to inform user of issue.
                self.alertMessage = "Reverse geocoder failed with error: " + error!.localizedDescription
                self.alertUser()
                
                return
            }
            
            // Ensure there is at least one placemark in the placemarks array.
            //if placemarks!.count > 0 {
            if let place = placemarks!.first {
                // Stop updating location as no longer necessary.
                self.locationManager.stopUpdatingLocation()
                
                // Get the first placemark.
                self.placemark = place
                
                print(self.placemark.locality)
                print(self.placemark.postalCode)
                print(self.placemark.administrativeArea)
                print(self.placemark.country)
                
                // Ensure there is a placemark.
                //if let place = self.placemark {
                    
                    // IMPORTANT: should I do something else with this?
                    
                    // Create a formatted string of placemark data.
                    let placeText = "\(place.locality), \(place.administrativeArea)  \(place.country)"
                    print("\(placeText)")
                //}
            }
        })
    }
    
    // Handle changed authorization status for location manager.
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        
        // Make user location available if authorized.
        self.mapView.showsUserLocation = (status == .AuthorizedAlways)
    }
    
    // Handle failed with error for location manager.
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        
        // Use UIAlertController to inform user of issue.
        let errorString = "Error while updating location " + error.localizedDescription
        self.alertMessage = errorString
        self.alertUser()
    }
    
    // Use UIAlertController to inform user of issue.
    func alertUser() {
        
        // Dispatch alert to main queue.
        dispatch_async(dispatch_get_main_queue(), {
            
            // Create an instance of alert controller.
            let alertController = UIAlertController(title: "Problem", message: self.alertMessage, preferredStyle: .Alert)
            
            // Ensure there is a message.
            if let message = self.alertMessage {
                alertController.message = message
            }
            
            // Set up an OK action button on alert.
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) -> Void in
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            
            // Add OK action button to alert.
            alertController.addAction(okAction)
            
            // Present alert controller.
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    func listFilesFromDocumentsFolder() {
        print("Trying to show directory")
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        print("Paths: \(paths)")
        let documentsDirectory = paths.first
        print("First Path / Directory: \(documentsDirectory)")
        //var directoryList = [String]()
        do {
            let directoryList = try NSFileManager.defaultManager().contentsOfDirectoryAtPath(documentsDirectory!) as [String]
            print("Files in Documents folder:")
            for d in directoryList {
                //directoriesString.appendContentsOf(d)
                print("\(d)")
            }
        } catch _ {
            print("Error in try statement for contents of directory")
        }
        
        
    }
    
}
