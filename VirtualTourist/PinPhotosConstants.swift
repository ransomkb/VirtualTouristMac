//
//  PinPhotosConstants.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import Foundation

extension PinPhotos {
    struct API {
        static let BASE = "https://"
        static let BASE_URL = "https://api.flickr.com/services/rest/"
        static let METHOD_NAME = "flickr.photos.search"
        static let API_KEY = "35c8d5a00d63b2ba2caf97759109cabf"
        static let EXTRAS = "url_m"
        static let SAFE_SEARCH = "1"
        static let DATA_FORMAT = "json"
        static let NO_JSON_CALLBACK = "1"
        static let PerPage = "21"
    }
    
    struct BBox {
        static let BOUNDING_BOX_HALF_WIDTH = 1.0
        static let BOUNDING_BOX_HALF_HEIGHT = 1.0
        static let LAT_MIN = -90.0
        static let LAT_MAX = 90.0
        static let LON_MIN = -180.0
        static let LON_MAX = 180.0
    }
    
    struct Keys {
        static let Total = "total"
        static let Page = "page"
        static let Pages = "pages"
        static let PerPage = "per_page"
        static let ID = "id"
        static let Title = "title"
        static let ErrorStatusMessage = "status_message"
        static let MethodKey = "method"
        static let Api_KeyKey = "api_key"
        static let Safe_SearchKey = "safe_search"
        static let ExtrasKey = "extras"
        static let FormatKey = "format"
        static let NojsonCallBackKey = "nojsoncallback"
        static let Per_PageKey = "per_page"
        static let BBoxKey = "bbox"
        static let PageKey = "page"
    }
}