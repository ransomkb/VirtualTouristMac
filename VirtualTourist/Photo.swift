//
//  Photo.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import UIKit
import CoreData

@objc(Photo)

class Photo: NSManagedObject {
    
    struct Keys {
        static let PhotoID = "id"
        static let Title = "title"
        static let ImagePath = "url_m"
    }
    
    @NSManaged var id: String
    @NSManaged var title: String
    @NSManaged var imagePath: String?
    @NSManaged var pin: Pin?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        
        id = dictionary[Keys.PhotoID] as! String
        title = dictionary[Keys.Title] as! String
        imagePath = dictionary[Keys.ImagePath] as? String
    }
    
    // Variable for accessing photos in caches
    var photoImage: UIImage? {
        get {
            return PinPhotos.Caches.imageCache.imageWithIdentifier(imagePath)
        }
        
        set {
            PinPhotos.Caches.imageCache.storeImage(newValue, withIdentifier: imagePath!)
        }
    }
    
}
