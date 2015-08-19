//
//  PinPhotos.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class PinPhotos: NSObject, NSFetchedResultsControllerDelegate {
    
    typealias CompletionHander = (parsedResult: AnyObject!, error: NSError?) -> Void
    
    var session: NSURLSession
    var searchTask: NSURLSessionDataTask?
    var alertMessage: String?
    
    var totalPages = 0
    var pageLimit = 0
    var randomPages = [Int]()
    
    //var deletePins = [Pin]()
    
    //var config = Config.unarchivedInstance() ?? Config()
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var pinFetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "longitude", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        }()
    
    lazy var photoFetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        }()
    
    func createBoundingBoxString(pin: Pin) -> String {
        let latitude = pin.latitude
        let longitude = pin.longitude
        
        let bottom_left_long = max(longitude - BBox.BOUNDING_BOX_HALF_WIDTH, BBox.LON_MIN)
        let bottom_left_lat = max(latitude - BBox.BOUNDING_BOX_HALF_HEIGHT, BBox.LAT_MIN)
        let top_right_long = min(longitude + BBox.BOUNDING_BOX_HALF_WIDTH, BBox.LON_MAX)
        let top_right_lat = min(latitude + BBox.BOUNDING_BOX_HALF_HEIGHT, BBox.LAT_MAX)
        
        let bboxString = "\(bottom_left_long),\(bottom_left_lat),\(top_right_long),\(top_right_lat)"
        println("\(bboxString)")
        
        return bboxString
    }
    
    func getTotalPhotos(hostViewController: UIViewController, pin: Pin, completionHandler: (success: Bool, errorString: String?) -> Void) {
        
        //println("Photos in fetched objects get album start: \(fetchedResultsController.fetchedObjects!.count)")
        
        var methodArguments: [String: AnyObject] = [
            "method": PinPhotos.API.METHOD_NAME,
            "api_key": PinPhotos.API.API_KEY,
            "bbox": createBoundingBoxString(pin),
            "safe_search": PinPhotos.API.SAFE_SEARCH,
            "extras": PinPhotos.API.EXTRAS,
            "format": PinPhotos.API.DATA_FORMAT,
            "nojsoncallback": PinPhotos.API.NO_JSON_CALLBACK,
            "per_page": PinPhotos.API.PerPage
        ]
        
        println("Getting a page number.")
        self.searchTask = PinPhotos.sharedInstance().taskForResource(methodArguments, completionHandler: { (parsedResult, error) -> Void in
            
            // Handle the error case
            if let error = error {
                let eString = "Error searching for photos: \(error.localizedDescription)"
                println(eString)
                completionHandler(success: false, errorString: eString)
                return
            }
            
            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                println("Got some photos")
                if let totalPages = photosDictionary["pages"] as? Int {
                    println("Total pages: \(totalPages)")
                    self.totalPages = totalPages
                    
                    // IMPORTANT: change this back to 42 before submission
                    self.pageLimit = min(totalPages, 6)
                    println("Page limit: \(self.pageLimit)")
                    
                    completionHandler(success: true, errorString: nil)
                } else {
                    let eString = "Can't find key 'pages' in \(photosDictionary)"
                    println(eString)
                    completionHandler(success: false, errorString: eString)
                }
            } else {
                let eString = "Can't find key 'photos' in \(parsedResult)"
                println(eString)
                completionHandler(success: false, errorString: eString)
            }
        })
        
//        getTotalPhotos(pin, arguments: methodArguments, completionHandler: { (success, errorString) -> Void in
//            if success {
//                println("Got total photos")
//                completionHandler(success: true, errorString: nil)
//            } else {
//                println(errorString)
//                completionHandler(success: false, errorString: errorString)
//            }
//        })
    }
    
//    func getTotalPhotos(pin: Pin, arguments: [String: AnyObject], completionHandler: (success: Bool, errorString: String?) -> Void) {
//        
//        println("Getting a page number.")
//        self.searchTask = PinPhotos.sharedInstance().taskForResource(arguments, completionHandler: { (parsedResult, error) -> Void in
//            
//            // Handle the error case
//            if let error = error {
//                self.alertMessage = "Error searching for photos: \(error.localizedDescription)"
//                println(self.alertMessage)
//                return
//            }
//            
//            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
//                println("Got some photos")
//                if let totalPages = photosDictionary["pages"] as? Int {
//                    println("Total pages: \(totalPages)")
//                    self.totalPages = totalPages
//                    
//                    // IMPORTANT: change this back to 42 before submission
//                    self.pageLimit = min(totalPages, 6)
//                    println("Page limit: \(self.pageLimit)")
//                    
//                    completionHandler(success: true, errorString: nil)
//                } else {
//                    let eString = "Can't find key 'pages' in \(photosDictionary)"
//                    println(eString)
//                    completionHandler(success: false, errorString: eString)
//                }
//            } else {
//                let eString = "Can't find key 'photos' in \(parsedResult)"
//                println(eString)
//            }
//        })
//    }
    
    // maybe will not use
    func getPhotosForAlbum(hostViewController: UIViewController, pin: Pin, completionHandler: (success: Bool, errorString: String?) -> Void) {
        
        var methodArguments: [String: AnyObject] = [
            "method": PinPhotos.API.METHOD_NAME,
            "api_key": PinPhotos.API.API_KEY,
            "bbox": createBoundingBoxString(pin),
            "safe_search": PinPhotos.API.SAFE_SEARCH,
            "extras": PinPhotos.API.EXTRAS,
            "format": PinPhotos.API.DATA_FORMAT,
            "nojsoncallback": PinPhotos.API.NO_JSON_CALLBACK,
            "per_page": PinPhotos.API.PerPage
        ]
        
        //for (var x = 0; x < pageLimit; ++x) {
            
            let page = self.randomPageGenerator()
            
            println("Getting a photo for page: \(page)")
            var withPageDictionary: [String:AnyObject] = methodArguments
            withPageDictionary["page"] = "\(page)"
            
            self.searchTask = PinPhotos.sharedInstance().taskForResource(withPageDictionary, completionHandler: { (parsedResult, error) -> Void in
                // Handle the error case
                if let error = error {
                    let eString = "Error searching for photos: \(error.localizedDescription)"
                    println(eString)
                    completionHandler(success: false, errorString: eString)
                    return
                }
                
                if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                    
                    var totalPhotosValue = 0
                    if let totalPhotos = photosDictionary["total"] as? String {
                        totalPhotosValue = (totalPhotos as NSString).integerValue
                    }
                    
//                    var perPage = 0
//                    if let per = photosDictionary[PinPhotos.Keys.PerPage] as? String {
//                        println("Number of photos per page: \(per)")
//                        perPage = (per as NSString).integerValue
//                    }
                    
                    if totalPhotosValue > 0 {
                        
                        println("Total photos: \(totalPhotosValue)")
                        if let photosArray = photosDictionary["photo"] as? [[String:AnyObject]] {
                            
                            println("Creating array of Photo entities from photo dictionary: \(photosArray)")
                            var photos = photosArray.map() {(dictionary: [String : AnyObject]) -> Photo in
                                let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                photo.pin = pin
                                println("Photo image path: \(photo.imagePath)")
                                return photo
                            }
                            //CoreDataStackManager.sharedInstance().saveContext()
                            completionHandler(success: true, errorString: nil)
                        } else {
                            completionHandler(success: false, errorString: "Error: no key called 'photo'")
                        }
                    } else {
                        completionHandler(success: false, errorString: "Error: totalPhtotos was 0 or less.")
                    }
                } else {
                    completionHandler(success: false, errorString: "Error: no key called 'photos'")
                }
            })

        //}
        
        //CoreDataStackManager.sharedInstance().saveContext()
        
        
        
//        self.getPhotoForAlbum(pin, page: page, arguments: methodArguments, completionHandler: { (success, errorString) -> Void in
//            if success {
//                println("Got a photo for a cell")
//                
//                completionHandler(success: true, errorString: nil)
//            } else {
//                println(errorString)
//                completionHandler(success: false, errorString: errorString)
//            }
//        })
        
    }
    
//    func getPhotoForAlbum(pin: Pin, page: Int, arguments: [String: AnyObject], completionHandler: (success: Bool, errorString: String?) -> Void) {
//        
//        println("Getting a photo for page: \(page)")
//        var withPageDictionary: [String:AnyObject] = arguments
//        withPageDictionary["page"] = "\(page)"
//        
//        self.searchTask = PinPhotos.sharedInstance().taskForResource(withPageDictionary, completionHandler: { (parsedResult, error) -> Void in
//            // Handle the error case
//            if let error = error {
//                self.alertMessage = "Error searching for photos: \(error.localizedDescription)"
//                println(self.alertMessage)
//                return
//            }
//            
//            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
//                
//                var totalPhotosValue = 0
//                if let totalPhotos = photosDictionary["total"] as? String {
//                    totalPhotosValue = (totalPhotos as NSString).integerValue
//                }
//                
////                var perPage = 0
////                if let per = photosDictionary[PinPhotos.Keys.PerPage] as? String {
////                    println("Number of photos per page: \(per)")
////                    perPage = (per as NSString).integerValue
////                }
//                
//                if totalPhotosValue > 0 {
//                    
//                    println("Total photos: \(totalPhotosValue)")
//                    if let photosArray = photosDictionary["photo"] as? [[String:AnyObject]] {
//                        
//                        println("Creating array of Photo entities from photo dictionary: \(photosArray)")
//                        var photos = photosArray.map() {(dictionary: [String : AnyObject]) -> Photo in
//                            let photo = Photo(dictionary: dictionary, context: self.sharedContext)
//                            photo.pin = pin
//                            println("Photo image path: \(photo.imagePath)")
//                            return photo
//                        }
//                        
//                        completionHandler(success: true, errorString: nil)
//                    } else {
//                        completionHandler(success: false, errorString: "Error: no key called 'photo'")
//                    }
//                } else {
//                    completionHandler(success: false, errorString: "Error: totalPhtotos was 0 or less.")
//                }
//            } else {
//                completionHandler(success: false, errorString: "Error: no key called 'photos'")
//            }
//        })
//    }

    func taskForResource(parameters: [String : AnyObject], completionHandler: CompletionHander) -> NSURLSessionDataTask {
        
        println("Starting Task")
        let urlString = API.BASE_URL + escapedParameters(parameters)
        println("URL String: \(urlString)")
        let url = NSURL(string: urlString)
        let request = NSURLRequest(URL: url!)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            println("Task started, URL String: \(urlString)")
            if let error = downloadError {
                let newError = PinPhotos.errorForData(data, response: response, error: error)
                completionHandler(parsedResult: nil, error: downloadError)
            } else {
                println("taskForResource's completionHandler is invoked.")
                PinPhotos.parseJSONWithCompletionHandler(data, completionHandler: completionHandler)
            }
        }
        
        task.resume()
        
        return task
    }
    
    //
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        println("Handling Error")
        if let parsedResult = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments, error: nil) as? [String : AnyObject] {
            if let errorMessage = parsedResult[Keys.ErrorStatusMessage] as? String {
                
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                
                return NSError(domain: "PinPhotos Error", code: 1, userInfo: userInfo)
            }
        }
        
        return error
    }
    
    // Parsing the JSON
    
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: CompletionHander) {
        
        println("Parsing JSON")
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError)
        println("Parsed Result: \(parsedResult)")
        
        if let error = parsingError {
            completionHandler(parsedResult: nil, error: error)
        } else {
            completionHandler(parsedResult: parsedResult, error: nil)
        }
    }
    
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        println("Escaping Parameters")
        var urlVars = [String]()
        
        for (key, value) in parameters {
            let stringValue: String = value as! String
            
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            let requestSnippet = key + "=" + "\(escapedValue!)"
            //println(requestSnippet)
            urlVars += [requestSnippet]
        }
        
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }
    
//    func cleanupPins() {
//        deletePins.map() {
//            self.sharedContext.deleteObject($0 as Pin)
//        }
//    }
    
    func randomPageGenerator() -> Int {
        
//        for (var x = 0; x < pageLimit; ++x) {
//            // Try getting one page from the random set
//            let randomPage = Int(arc4random_uniform(UInt32(totalPages))) + 1
//            self.randomPages.append(randomPage)
//        }

        return Int(arc4random_uniform(UInt32(self.totalPages))) + 1
    }
    
    func deletePin(pin: Pin) {
        println("Deleting a pin")
        deletePhotosForPin(pin)
        //self.deletePins.append(pin)
        sharedContext.deleteObject(pin)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    func deleteAllPins() {
        println("Deleting pins")
        let fetched = pinFetchedResultsController.fetchedObjects
        
        fetched?.map() {
            //self.deletePins.append($0 as! Pin)
            self.deletePhotosForPin($0 as! Pin)
        }
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    func deletePhotosForPin(pin: Pin) {
        let photos = pin.photos as [Photo]
        for p in photos {
            p.pin = nil
            p.photoImage = nil
            sharedContext.deleteObject(p)
        }
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    // MARK: - Shared Instance
    
    class func sharedInstance() -> PinPhotos {
        
        struct Singleton {
            static var sharedInstance = PinPhotos()
        }
        
        return Singleton.sharedInstance
    }
    
    // MARK: - Shared Image Cache
    
    struct Caches {
        static let imageCache = ImageCache()
    }

}