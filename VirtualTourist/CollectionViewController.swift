//
//  CollectionViewController.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreLocation
import CoreData


class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    private let reuseIdentifier = "PhotoCell"
    private let sectionInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 5.0, right: 2.0)
    
    var selectedIndexes = [NSIndexPath]()
    
    // Keep track of insertions, deletions, and updates.
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    var coordinate: CLLocationCoordinate2D?
    var regionSpan: MKCoordinateSpan?
    
    var alertMessage: String?
    
    var pin: Pin?
    
    
    var sharedContext: NSManagedObjectContext = CoreDataStackManager.sharedInstance().managedObjectContext!
    
    var region: MKCoordinateRegion {
        return MKCoordinateRegionMake(coordinate!, regionSpan!)
    }
    
    // May not need this
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        return url.URLByAppendingPathComponent("zoomDictionary").path!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    
    @IBAction func cancelActivities(sender: AnyObject) {
        NSOperationQueue.mainQueue().addOperationWithBlock {
            //self.activityIndicatorView.stopAnimating()
            
            self.navigationController?.popToRootViewControllerAnimated(true)
        }
    }

    @IBAction func fetchNewCollection(sender: AnyObject) {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        println("View did load.")
        
        // Start the fetched results controller
        var error: NSError?
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        
        fetchedResultsController.delegate = self
        
        mapView.delegate = self

    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if let pin = pin {
            println("Collection Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
            coordinate = pin.coordinate
            mapView.setRegion(region, animated: true)
            mapView.addAnnotation(pin)
        } else {
            cancelActivities(self)
        }
    }
    
    // Layout the collection view
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
//        if var size = photo.thumbnail?.size {
//            size.width += 10
//            size.height += 10
//            return size
//        }
        return CGSize(width: 100, height: 100)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return sectionInsets
        
    }
    
    // MARK - Configure Cell
    // maybe do not need
    func configureCell(cell: TaskCancellingCollectionViewCell, photo: Photo) {
        
        var coordintateImage = UIImage(named: "posterPlaceHoldr")
        
        cell.imageView!.image = nil
        
        // Set the Photo Image
        if photo.imagePath == nil || photo.imagePath == "" {
            coordintateImage = UIImage(named: "noImage")
        } else if photo.photoImage != nil {
            coordintateImage = photo.photoImage
        } else {
            
        }
        
        cell.imageView!.image = coordintateImage
    }
    
    // MARK - UICollectionView
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        
        println("Number of Cells: \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! TaskCancellingCollectionViewCell
        cell.backgroundColor = UIColor.blackColor()
        self.configureCell(cell, photo: photo)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! TaskCancellingCollectionViewCell
        
        if let index = find(selectedIndexes, indexPath) {
            selectedIndexes.removeAtIndex(index)
        } else {
            selectedIndexes.append(indexPath)
        }
        
        //configureCell(cell, photo: photo)
        
        collectionView.deleteItemsAtIndexPaths(selectedIndexes)
        sharedContext.deleteObject(photo)
        CoreDataStackManager.sharedInstance().saveContext()
        
        collectionView.reloadData()
    }
    
    
    // MARK: - Fetched Results Controller Delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()

    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        println("in controllerDidChangeContent. changes.count: \(insertedIndexPaths.count + deletedIndexPaths.count)")
        
        collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
        switch type {
        case .Insert:
            self.collectionView.insertSections(NSIndexSet(index: sectionIndex))
            
        case .Delete:
            self.collectionView.deleteSections(NSIndexSet(index: sectionIndex))
            
        default:
            return
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type{
            
        case .Insert:
            println("Inserting an item")
            insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            println("Deleting an item")
            deletedIndexPaths.append(indexPath!)
            break
        case .Update:
            println("Updating an item.")
            updatedIndexPaths.append(indexPath!)
            break
        case .Move:
            println("Moving an item. We don't expect to see this in this app.")
            break
        default:
            break
        }
    }
    
    // MARK - Misc Activities
    
    func alertUser() {
        dispatch_async(dispatch_get_main_queue(), {
            let alertController = UIAlertController(title: "Problem", message: self.alertMessage, preferredStyle: .Alert)
            
            if let message = self.alertMessage {
                alertController.message = message
            }
            
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) -> Void in
                //self.dismissViewControllerAnimated(true, completion: nil)
            }
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    
}