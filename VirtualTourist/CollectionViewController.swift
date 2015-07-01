//
//  CollectionViewController.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import Foundation
import UIKit


class CollectionViewController: UIViewController {
    
    @IBAction func cancelActivities(sender: AnyObject) {
        NSOperationQueue.mainQueue().addOperationWithBlock {
            //self.activityIndicatorView.stopAnimating()
            
            let controller = self.storyboard!.instantiateViewControllerWithIdentifier("MapViewController") as! MapViewController
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }

}