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

    
    // Initialize the super with the entity and context info.
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    // Use a convenience initializer.
    init(context: NSManagedObjectContext) {
        
        // Fetch the entity named Pin.
        let entity =  NSEntityDescription.entityForName("Step", inManagedObjectContext: context)!
        
        // Initiate the parent class with the entity and context.
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // IMPORTANT: does not seem to print; remove?
        print("Photo created without dictionary")
        
        title = "No Name"
        imagePath = "placeholder"
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
        //imagePath = dictionary[Keys.ImagePath] as? String
        if let wholeString = dictionary[Keys.ImagePath] as? String {
            print("Removing https:// to create a subset of data.")
            /* subset response data! */
            let subString = wholeString.substringFromIndex((imagePath?.startIndex.advancedBy(8))!)
            imagePath = subString // Maybe 8 is better if starts from
            //subdataWithRange(NSMakeRange(5, imagePath.length - 5))
        }
    }
    
    func updateDetails(dictionary: [String : AnyObject]) {
        // Set properties with dictionary data.
        id = dictionary[Keys.PhotoID] as! String
        title = dictionary[Keys.Title] as! String
        //imagePath = dictionary[Keys.ImagePath] as? String
        if let wholeString = dictionary[Keys.ImagePath] as? String {
            print("Removing https:// to create a subset of data.")
            /* subset response data! */
            let subString = wholeString.substringFromIndex((imagePath?.startIndex.advancedBy(8))!)
            imagePath = subString // Maybe 8 is better if starts from
            //subdataWithRange(NSMakeRange(5, imagePath.length - 5))
        }
    }
    
}
