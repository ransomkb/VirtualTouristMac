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

// Handles functions related to Pin and Photo entity classes.
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
    
    // Computed property for a shared context of Core Data.
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Lazy computed property returning a fetched results controller for Pin entities sorted by longitude.
    lazy var pinFetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "longitude", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        }()
    
    // Lazy computed property returning a fetched results controller for Photo entities sorted by title.
    lazy var photoFetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        }()
    
    // Create a Bounding Box string for Flickr using longitude and latitude of a Pin.
    func createBoundingBoxString(pin: Pin) -> String {
        let latitude = pin.latitude
        let longitude = pin.longitude
        
        let bottom_left_long = max(longitude - BBox.BOUNDING_BOX_HALF_WIDTH, BBox.LON_MIN)
        let bottom_left_lat = max(latitude - BBox.BOUNDING_BOX_HALF_HEIGHT, BBox.LAT_MIN)
        let top_right_long = min(longitude + BBox.BOUNDING_BOX_HALF_WIDTH, BBox.LON_MAX)
        let top_right_lat = min(latitude + BBox.BOUNDING_BOX_HALF_HEIGHT, BBox.LAT_MAX)
        
        let bboxString = "\(bottom_left_long),\(bottom_left_lat),\(top_right_long),\(top_right_lat)"
        print("\(bboxString)")
        
        return bboxString
    }
    
    // Get the total number of photos available on Flickr for a Pin using its longitude and latitude.
    // Report success with a completion handler.
    func getTotalPhotos(hostViewController: UIViewController, pin: Pin, completionHandler: (success: Bool, errorString: String?) -> Void) {
        
        //println("Photos in fetched objects get album start: \(fetchedResultsController.fetchedObjects!.count)")
        
        // Create the dictionary of arguments for request with BBox from Pin.
        let methodArguments: [String: AnyObject] = [
            "method": PinPhotos.API.METHOD_NAME,
            "api_key": PinPhotos.API.API_KEY,
            "bbox": createBoundingBoxString(pin),
            "safe_search": PinPhotos.API.SAFE_SEARCH,
            "extras": PinPhotos.API.EXTRAS,
            "format": PinPhotos.API.DATA_FORMAT,
            "nojsoncallback": PinPhotos.API.NO_JSON_CALLBACK,
            "per_page": PinPhotos.API.PerPage
        ]
        
        print("Getting a page number.")
        
        // Assign a search task using request arguments.
        // Use a completion handler to return the parsed json results.
        self.searchTask = PinPhotos.sharedInstance().taskForResource(methodArguments, completionHandler: { (parsedResult, error) -> Void in
            
            // Handle the error case
            if let error = error {
                
                // Report error with localized string.
                let eString = "Error searching for photos: \(error.localizedDescription)"
                print(eString)
                
                // Report failure and error details.
                completionHandler(success: false, errorString: eString)
                return
            }
            
            // Make sure there is a photos key.
            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                print("Got some photos")
                
                // Make sure there is a pages key pointing to total number of pages.
                if let totalPages = photosDictionary["pages"] as? Int {
                    print("Total pages: \(totalPages)")
                    
                    // Set totalPages for future fetching with random selection.
                    if totalPages > 190 {
                        self.totalPages = 190
                    } else {
                        self.totalPages = totalPages
                    }
                    
                    // Report success.
                    completionHandler(success: true, errorString: nil)
                } else {
                    
                    // Create string to explain that there is no key called pages in the json dictionary.
                    let eString = "Can't find key 'pages' in \(photosDictionary)"
                    print(eString)
                    
                    // Report failure and error details.
                    completionHandler(success: false, errorString: eString)
                }
            } else {
                
                // Create string to explain that there is no key called photos in the parsed json.
                let eString = "Can't find key 'photos' in \(parsedResult)"
                print(eString)
                
                // Report failure and error details.
                completionHandler(success: false, errorString: eString)
            }
        })
    }
    
    // Get the photos on Flickr for a Pin, using its longitude and latitude, to be used in an album.
    // Report success with a completion handler.
    func getPhotosForAlbum(hostViewController: UIViewController, pin: Pin, completionHandler: (success: Bool, errorString: String?) -> Void) {
        
        // Create the dictionary of arguments for request with BBox from Pin.
        let methodArguments: [String: AnyObject] = [
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
            
        // Return an integer generated randomly from the total number of pages.
        let page = self.randomPageGenerator()
            
            print("Getting a photo for page: \(page)")
        
        // Create a new argument dictionary with additional key called page to limit number of photos returned.
            var withPageDictionary: [String:AnyObject] = methodArguments
            withPageDictionary["page"] = "\(page)"
            
        // Assign a search task using request arguments.
        // Use a completion handler to return the parsed json results.
        self.searchTask = PinPhotos.sharedInstance().taskForResource(withPageDictionary, completionHandler: { (parsedResult, error) -> Void in
            
            // Check for error.
                if let error = error {
                    
                    // Report error with localized string.
                    let eString = "Error searching for photos: \(error.localizedDescription)"
                    print(eString)
                    
                    // Report failure and error details.
                    completionHandler(success: false, errorString: eString)
                    return
                }
                
            // Make sure there is a photos key.
            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                    
                    var totalPhotosValue = 0
                
                // Make sure there is a total key.
                    if let totalPhotos = photosDictionary["total"] as? String {
                        
                        // Convert total string to integer.
                        totalPhotosValue = (totalPhotos as NSString).integerValue
                    }
                    
//                    var perPage = 0
//                    if let per = photosDictionary[PinPhotos.Keys.PerPage] as? String {
//                        println("Number of photos per page: \(per)")
//                        perPage = (per as NSString).integerValue
//                    }
                
                // Make sure at least one photo.
                    if totalPhotosValue > 0 {
                        
                        print("Total photos: \(totalPhotosValue)")
                        
                        // Make sure there is a photo key to retrieve the array of dictionaries of photo details from the parsed JSON.
                        if let photosArray = photosDictionary["photo"] as? [[String:AnyObject]] {
                            
                            print("Creating array of Photo entities from photo dictionary: \(photosArray)")
                            
                            // IMPORTANT: make this a temporary context, then check shared context for same id.
                            // Create a Photo class and entity value for each photo in the array using its dictionary.
                            _ = photosArray.map() {(dictionary: [String : AnyObject]) -> Photo in
                                let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                
                                // Set the pin variable in photo to that passed through this function.
                                photo.pin = pin
                                print("Photo image path: \(photo.imagePath)")
                                return photo
                            }
                            
                            // IMPORTANT: maybe wish to save here. Check if photo with same id already exists.
                            //CoreDataStackManager.sharedInstance().saveContext()
                            
                            // Report success in getting photos from flickr and creating photo instances for Core Data.
                            completionHandler(success: true, errorString: nil)
                        } else {
                            // Report failure and error details.
                            completionHandler(success: false, errorString: "Error: no key called 'photo'")
                        }
                    } else {
                        // Report failure and error details.
                        completionHandler(success: false, errorString: "Error: totalPhtotos was 0 or less.")
                    }
                } else {
                    // Report failure and error details.
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
    
    // Create a session data task for requesting data from Flickr with a RESTful request using a dictionary of parameters.
    // Use a completion handler to return parsed json data.
    func taskForResource(parameters: [String : AnyObject], completionHandler: CompletionHander) -> NSURLSessionDataTask {
        
        print("Starting Task")
        
        // Create the string of the url from the base url and the escaped parameters.
        let urlString = API.BASE_URL + escapedParameters(parameters)
        print("URL String: \(urlString)")
        let url = NSURL(string: urlString)
        
        // Create the request from the url string.
        let request = NSURLRequest(URL: url!)
        
        // Create a session data task from the request.
        // Use a completion handler to deal with response data.
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            print("Task started, URL String: \(urlString)")
            
            // Check if there is an error.
            if let error = downloadError {
                
                // Create an error with json data from the response.
                _ = PinPhotos.errorForData(data, response: response, error: error)
                
                // Report the failure and the error data.
                completionHandler(parsedResult: nil, error: downloadError)
            } else {
                print("taskForResource's completionHandler is invoked.")
                
                
                // Parse JSON data using a completion handler to return the results.
                PinPhotos.parseJSONWithCompletionHandler(data!, completionHandler: completionHandler)
            }
        }
        
        task.resume()
        
        return task
    }
    
    // Create an error with json data from the response.
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        print("Handling Error")
        
        // Check that there is a dictionary of json data.
        if let parsedResult = (try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments)) as? [String : AnyObject] {
            
            // Check that there is a key correspoding to the error status message.
            if let errorMessage = parsedResult[Keys.ErrorStatusMessage] as? String {
                
                // Localize the error message.
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                
                // Return the error details.
                return NSError(domain: "PinPhotos Error", code: 1, userInfo: userInfo)
            }
        }
        
        // Return original error as there was no json data.
        return error
    }
    
    // Parse JSON data using a completion handler to return the results.
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: CompletionHander) {
        
        print("Parsing JSON")
        var parsingError: NSError? = nil
        
        // Parse the json data in the response result.
        let parsedResult: AnyObject?
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
        } catch let error as NSError {
            parsingError = error
            parsedResult = nil
        }
        print("Parsed Result: \(parsedResult)")
        
        // Check for a parsing error.
        if let error = parsingError {
            
            // Report the failure and the parsing error.
            completionHandler(parsedResult: nil, error: error)
        } else {
            
            // Return parsed results.
            completionHandler(parsedResult: parsedResult, error: nil)
        }
    }
    
    // Escape the parameters dictionary objects to create a string suitable for the url of a RESTful request.
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        print("Escaping Parameters")
        
        // Create an array of string variables for the url.
        var urlVars = [String]()
        
        // Iterate through the parameters dictionary.
        for (key, value) in parameters {
            
            // Ensure the values are strings.
            let stringValue: String = value as! String
            
            // Use percent encoding to escape difficult characters.
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            // Create the key / value pair and add it to the array of url variables.
            let requestSnippet = key + "=" + "\(escapedValue!)"
            //println(requestSnippet)
            urlVars += [requestSnippet]
        }
        
        // Return string of joined url variables separated by &.
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
//    func cleanupPins() {
//        deletePins.map() {
//            self.sharedContext.deleteObject($0 as Pin)
//        }
//    }
    
    // Return an integer generated randomly from the total number of pages.
    func randomPageGenerator() -> Int {
        
//        for (var x = 0; x < pageLimit; ++x) {
//            // Try getting one page from the random set
//            let randomPage = Int(arc4random_uniform(UInt32(totalPages))) + 1
//            self.randomPages.append(randomPage)
//        }

        return Int(arc4random_uniform(UInt32(self.totalPages))) + 1
    }
    
//    func deletePin(pin: Pin) {
//        println("Deleting a pin")
//        deletePhotosForPin(pin)
//        //self.deletePins.append(pin)
//        sharedContext.deleteObject(pin)
//        CoreDataStackManager.sharedInstance().saveContext()
//    }
//    
//    func deleteAllPins() {
//        println("Deleting pins")
//        let fetched = pinFetchedResultsController.fetchedObjects
//        
//        fetched?.map() {
//            //self.deletePins.append($0 as! Pin)
//            self.deletePhotosForPin($0 as! Pin)
//        }
//        CoreDataStackManager.sharedInstance().saveContext()
//    }
    
    // Delete all the photos related to a pin
    func deletePhotosForPin(pin: Pin) {
        
        //let photos = pin.photos as [Photo]
        
        // Delete all the photos from the Pin.
        for p in pin.photos as [Photo] {
            p.pin = nil
            p.photoImage = nil
            sharedContext.deleteObject(p)
        }
        
        // Save the context.
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    // MARK: - Shared Instance
    
    // Create a shared instance singleton for PinPhotos.
    class func sharedInstance() -> PinPhotos {
        
        struct Singleton {
            static var sharedInstance = PinPhotos()
        }
        
        return Singleton.sharedInstance
    }
    
    // MARK: - Shared Image Cache
    
    // Creates a shared image cache.
    struct Caches {
        static let imageCache = ImageCache()
    }
    
    // Pasted in to remove https:// from url for directory storage.
    // Get a subset of the data to conform to Udacity requirements, if udacity Bool is true.
//    if udacity {
//    print("udacity was true, so getting subset of data.")
//    /* subset response data! */
//    newData = data!.subdataWithRange(NSMakeRange(5, data!.length - 5))
//    }
    
    
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
}