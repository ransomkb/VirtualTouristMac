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

// Stores and manipulates CoreData entity objects called Photo
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
    
    // Initialize the super with the entity and context info.
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // Initialize the class with context and dictionary.
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Create the Photo entity.
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        
        // Initialize the super with the entity and context info.
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        
        // Set properties with dictionary data.
        id = dictionary[Keys.PhotoID] as! String
        title = dictionary[Keys.Title] as! String
        imagePath = dictionary[Keys.ImagePath] as? String
    }
    
    // Computed property for accessing photos in caches
    var photoImage: UIImage? {
        get {
            print("Getting image at imagePath: \(imagePath)")
            
            // Return a cached image stored under the imagePath.
            return PinPhotos.Caches.imageCache.imageWithIdentifier(imagePath)
        }
        
        set {
            print("Storing image at imagePath: \(imagePath)")
            
            // Store or update the image in the cache under the imagePath.
            PinPhotos.Caches.imageCache.storeImage(newValue, withIdentifier: imagePath!)
        }
    }
    
}
