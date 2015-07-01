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
    @NSManaged var latitude: CLLocationDegrees
    @NSManaged var longitude: CLLocationDegrees
    
    var coordinate: CLLocationCoordinate2D {
        var coords = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return coords
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        
        title = dictionary[Keys.Title] as! String
        address = dictionary[Keys.Address] as! String
        latitude = dictionary[Keys.Latitude] as! CLLocationDegrees
        longitude = dictionary[Keys.Longitude] as! CLLocationDegrees
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
    
        
}
