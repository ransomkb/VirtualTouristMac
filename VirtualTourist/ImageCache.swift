//
//  File.swift
//  VirtualTourist
//
//  Created by Jason on 1/31/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

class ImageCache {
    
    private var inMemoryCache = NSCache()
    
    // MARK: - Retreiving images
    
    func imageWithIdentifier(identifier: String?) -> UIImage? {
        
        // If the identifier is nil, or empty, return nil
        if identifier == nil || identifier! == "" {
            return nil
        }
        
        let path = pathForIdentifier(identifier!)
        print("Getting image with identifier: \(path)")
        
        // why do we need this?
        //var data: NSData?
        
        // First try the memory cache
        if let image = inMemoryCache.objectForKey(path) as? UIImage {
            print("Image was in the cache")
            return image
        }
        
        // Next Try the hard drive
        if let data = NSData(contentsOfFile: path) {
            print("Image was not in the cache, so trying the file.")
            return UIImage(data: data)
        }
        
        print("Image was in neither cache nor file, so returning nil.")
        return nil
    }
    
    // MARK: - Saving images
    
    func storeImage(image: UIImage?, withIdentifier identifier: String) {
        
        print("Storing image")
        let path = pathForIdentifier(identifier)
        print("Stored at path: \(path)")
        
        // If the image is nil, remove images from the cache
        if image == nil {
            
            print("Removing the object at path: \(path)")
            inMemoryCache.removeObjectForKey(path)
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch _ {
            }
            return
        }
        
        // Otherwise, keep the image in memory
        inMemoryCache.setObject(image!, forKey: path)
        
        // And in documents directory
        let data = UIImagePNGRepresentation(image!)
        data!.writeToFile(path, atomically: true)
    }
    
    // MARK: - Helper
    
    func pathForIdentifier(identifier: String) -> String {
        let documentsDirectoryURL: NSURL = (NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first)!
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        
        return fullURL.path!
    }
}