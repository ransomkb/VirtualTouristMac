//
//  PinPhotos.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import Foundation

class PinPhotos: NSObject {
    
    typealias CompletionHander = (parsedResult: AnyObject!, error: NSError?) -> Void
    
    var session: NSURLSession
    var searchTask: NSURLSessionDataTask?
    var alertMessage: String?
    
    //var config = Config.unarchivedInstance() ?? Config()
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
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

    func taskForResource(parameters: [String : AnyObject], completionHandler: CompletionHander) -> NSURLSessionDataTask {
        
        println("Starting Task")
        let urlString = API.BASE_URL + escapedParameters(parameters)
        println("URL String: \(urlString)")
        let url = NSURL(string: urlString)
        let request = NSURLRequest(URL: url!)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
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