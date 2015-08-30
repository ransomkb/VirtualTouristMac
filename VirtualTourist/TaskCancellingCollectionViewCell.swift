//
//  TaskCancellingCollectionViewCell.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 7/5/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import UIKit

class TaskCancellingCollectionViewCell: UICollectionViewCell {
    // The property uses a property observer. Any time its
    // value is set it canceles the previous NSURLSessionTask
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var imageName: String = ""
    
    var taskToCancelifCellIsReused: NSURLSessionTask? {
        didSet {
            
            // Ensure there was a previous value.
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }
    
    // IMPORTANT: may be unnecessary as selected is not used.
    // Ensure all preparations have been made.
    override func awakeFromNib() {
        super.awakeFromNib()
        self.selected = false
    }
    
//    override var selected : Bool {
//        didSet {
//            self.backgroundColor = selected ? UIColor.whiteColor() : UIColor.blackColor()
//        }
//    }
}
