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

class Pin: NSManagedObject, MKAnnotation {
    
    struct Keys {
        static let Title = "title"
        static let Address = "address"
        static let Latitude = "latitude"
        static let Longitude = "longitude"
    }
    
    @NSManaged var title: String
    @NSManaged var address: String
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var photos: [Photo]
    
    var coordinate: CLLocationCoordinate2D {
        get {
            let lat: CLLocationDegrees = latitude
            let lon: CLLocationDegrees = longitude
            var coords = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            return coords
        }
        
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
            updateAddress()
        }
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        
        title = dictionary[Keys.Title] as! String
        address = dictionary[Keys.Address] as! String
        latitude = dictionary[Keys.Latitude] as! Double
        longitude = dictionary[Keys.Longitude] as! Double
        
        println("Title: \(title)")
        println("Address: \(address)")
        println("Latitude: \(latitude)")
        println("Longitude: \(longitude)")
        println("Coordinate lat: \(coordinate.latitude)")
        println("Coordinate lon: \(coordinate.longitude)")
    }
    
    var subtitle: String {
        return address
    }
    
    // practice for learning about map items and placemarks
    func mapItem() -> MKMapItem {
        let addressDictionary = [String(kABPersonURLProperty): subtitle]
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDictionary)
        
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title
        
        return mapItem
    }
    
    func updateAddress() {
        let pinLocation = CLLocation(latitude: latitude, longitude: longitude)
        
        CLGeocoder().reverseGeocodeLocation(pinLocation, completionHandler: {(placemarks, error) -> Void in
            if (error != nil) {
                let message = "Reverse geocoder for Pin failed with error: " + error.localizedDescription
                println("\(message)")
                
                return
            }

            if placemarks.count > 0 {
                let place = placemarks[0] as! CLPlacemark
                self.title = "\(place.administrativeArea)"
                self.address = "\(place.locality), \(place.administrativeArea)  \(place.country)"
                println("\(self.address)")
            }
        })
    }
    
}
