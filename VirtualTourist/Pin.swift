//
//  Pin.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import UIKit
import CoreData
import AddressBook
import MapKit

@objc(Pin)

// Stores and manipulates CoreData entity objects called Pin
class Pin: NSManagedObject, MKAnnotation {
    
    struct Keys {
        static let Title = "title"
        static let Address = "address"
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    @NSManaged var title: String?
    @NSManaged var address: String
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var photos: [Photo]
    
    
    // Computed property to determine / set the coordinate
    var coordinate: CLLocationCoordinate2D {
        get {
            let lat: CLLocationDegrees = latitude
            let lon: CLLocationDegrees = longitude
            let coords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            return coords
        }
        
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
            updateAddress()
        }
    }
    
    // Initiate the parent class with the entity and context.
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // Use a convenience initializer to prepare parent and properties.
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Fetch the entity named Pin.
        let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        // Initiate the parent class with the entity and context.
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Use the dictionary to assign values to entity properties.
        title = dictionary[Keys.Title] as! String
        address = dictionary[Keys.Address] as! String
        latitude = dictionary[Keys.Latitude] as! Double
        longitude = dictionary[Keys.Longitude] as! Double
        
        print("Title: \(title)")
        print("Address: \(address)")
        print("Latitude: \(latitude)")
        print("Longitude: \(longitude)")
        print("Coordinate lat: \(coordinate.latitude)")
        print("Coordinate lon: \(coordinate.longitude)")
    }
    
    // Computed property for pin annotation.
    var subtitle: String? {
        return address
    }
    
    // Update the address related fields for pin annotations.
    func updateAddress() {
        
        // Use latitude and longitude variables to create a location.
        let pinLocation = CLLocation(latitude: latitude, longitude: longitude)
        
        // Use the location to reverse geocode the address details.
        CLGeocoder().reverseGeocodeLocation(pinLocation, completionHandler: {(placemarks, error) -> Void in
            
            // Check for an error.
            if (error != nil) {
                
                // Print the error.
                let message = "Reverse geocoder for Pin failed with error: " + error.localizedDescription
                print("\(message)")
                
                return
            }

            // Make sure there is at least one place in the placemarkes array.
            if placemarks.count > 0 {
                
                // Get the first place.
                let place = placemarks[0] as! CLPlacemark
                
                // Set the variables of self.
                self.title = "\(place.administrativeArea)"
                self.address = "\(place.locality), \(place.administrativeArea)  \(place.country)"
                
                print("\(self.address)")
            }
        })
    }
    
}
