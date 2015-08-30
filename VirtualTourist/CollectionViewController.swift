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

//protocol CollectionViewControllerDelegate {
//    func removeAnnotation(collectionViewController: CollectionViewController, withPin pin: Pin?)
//}

// Controls a collection view of photos, either stored locally or on Flickr.
class CollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, MKMapViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var newCollectionButton: UIButton!
    
    //var delegate: CollectionViewControllerDelegate?
    
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
    
    var pin: Pin!
    var photos = [Photo]()
    
    
    var searchTask: NSURLSessionDataTask?
    
    var sharedContext: NSManagedObjectContext = CoreDataStackManager.sharedInstance().managedObjectContext!
    
    // NEXT
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
        
        //return PinPhotos.sharedInstance().photoFetchedResultsController
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    @IBAction func backToMap(sender: AnyObject) {
        // Cancel the last task
        if let task = searchTask {
            task.cancel()
        }
        
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.navigationController!.popToRootViewControllerAnimated(true)
        }
    }
    
    @IBAction func cancelActivities(sender: AnyObject) {
        
        // Cancel the last task
        if let task = searchTask {
            task.cancel()
        }
        
        println("Canceled: Deleting photos")
        PinPhotos.sharedInstance().deletePhotosForPin(self.pin!)
        
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.navigationController!.popToRootViewControllerAnimated(true)
        }
    }
    
    @IBAction func fetchNewCollection(sender: AnyObject) {
        println("Fetch new collection tapped")
        
        // Cancel the last task
        if let task = searchTask {
            task.cancel()
        }
        
        println("NewCollection: Deleting photos")
        PinPhotos.sharedInstance().deletePhotosForPin(self.pin!)
        
        CoreDataStackManager.sharedInstance().saveContext()
        
        //fetchNewAlbum()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        println("Collection View did load.")
        
        // Start the fetched results controller
        var error: NSError?
        fetchedResultsController.performFetch(&error)
        
        if let error = error {
            
            // Use UIAlertController to inform user of issue.
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        
        fetchedResultsController.delegate = self
        
        mapView.delegate = self
        
        println("View  did load. Photos in fetched objects: \(fetchedResultsController.fetchedObjects!.count)")
        
        fetchTotalPages()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        println("Collection View will appear")
        
        if let pin = pin {
            println("Collection Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
            coordinate = pin.coordinate
            mapView.setRegion(region, animated: true)
            mapView.addAnnotation(pin)
        } else {
            cancelActivities(self)
        }
        
        println("View will appear. Photos in fetched objects: \(fetchedResultsController.fetchedObjects!.count)")
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if pin.photos.isEmpty {
            newCollectionButton.hidden = true
            println("pin.photos is empty")
            //fetchNewAlbum()
        }
        
        println("View did appear. Photos in fetched objects after getting album: \(self.fetchedResultsController.fetchedObjects!.count)")
        
//        PinPhotos.sharedInstance().getAPhotoForACell(self, pin: self.pin) { (success, errorString) -> Void in
//            if success {
//                CoreDataStackManager.sharedInstance().saveContext()
//                println("Getting album succeeded. Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
//            } else {
//                self.alertMessage = errorString
//                self.alertUser()
//            }
//        }
    }
    
    func fetchTotalPages() {
        
        println("Fetching Total Pages")
        
        PinPhotos.sharedInstance().getTotalPhotos(self, pin: pin) { (success, errorString) -> Void in
            if success {
                
                println("Did Set Total pages: \(PinPhotos.sharedInstance().totalPages)")
                //CoreDataStackManager.sharedInstance().saveContext()
                
                // too early; nothing to reload
                // Reload the table on the main thread
                //                dispatch_async(dispatch_get_main_queue()) {
                //                    self.collectionView!.reloadData()
                //                }
            } else {
                
                // Use UIAlertController to inform user of issue.
                self.alertMessage = errorString
                self.alertUser()
            }
        }

    }
    
    func fetchNewAlbum() {
        
        println("Fetching a New Album")
//        let pageLimit = PinPhotos.sharedInstance().pageLimit
//        println("Got a total of \(pageLimit) photos ready")
        
        PinPhotos.sharedInstance().getPhotosForAlbum(self, pin: self.pin) { (success, errorString) -> Void in
            if success {
                println("Getting album photo succeeded. Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
                self.newCollectionButton.hidden = false
            } else {
                
                // Use UIAlertController to inform user of issue.
                self.alertMessage = errorString
                self.alertUser()
            }
        }
        
//        for (var x = 0; x < pageLimit; ++x) {
//            self.fetchPhoto()
//        }

    }
    
    func fetchPhoto() {
        PinPhotos.sharedInstance().getPhotosForAlbum(self, pin: self.pin) { (success, errorString) -> Void in
            if success {
                println("Getting album photo succeeded. Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
                self.newCollectionButton.hidden = false
            } else {
                
                // Use UIAlertController to inform user of issue.
                self.alertMessage = errorString
                self.alertUser()
            }
        }
    }
    
    
    // Layout the collection view
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        println("Checking collection view layout size for item at index path.")
        //let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
//        if var size = photo.thumbnail?.size {
//            size.width += 10
//            size.height += 10
//            return size
//        }
        return CGSize(width: 100, height: 100)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        println("Checking collection view layout inset for section: \(section) at index.")
        //println("Section Insets: \(sectionInsets)")
        return sectionInsets
    }
    
    // MARK - Configure Cell
    // maybe do not need
    func configureCell(cell: TaskCancellingCollectionViewCell, photo: Photo) {
        println("Configuring a cell")
        
        var coordinateImage = UIImage(named: "posterPlaceHolder")
        
        cell.imageView!.image = nil
        
        // Set the Photo Image
        if photo.imagePath == nil || photo.imagePath == "" {
            println("No Image")
            coordinateImage = UIImage(named: "noImage")
        } else if photo.photoImage != nil {
            println("PhotoImage is not nil")
            coordinateImage = photo.photoImage
        } else {
            println("Photo has an image name, but it is not downloaded yet.")
            
            println(photo.imagePath)
            let imageURL = NSURL(string: photo.imagePath!)
            
            if let imageData = NSData(contentsOfURL: imageURL!) {
                //do all updates on main thread
                photo.photoImage = UIImage(data: imageData)
                coordinateImage = photo.photoImage
                
//                dispatch_async(dispatch_get_main_queue(), {
//                    //keep these updates minimal!!!
//                    cell.activityIndicator.stopAnimating()
//                    cell.imageView!.image = coordinateImage
//                })
            }
        }
        //cell.activityIndicator.stopAnimating()
        //cell.imageView!.image = coordinateImage
        //println("Configuring; Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
        
        dispatch_async(dispatch_get_main_queue(), {
            //keep these updates minimal!!!
            cell.activityIndicator.stopAnimating()
            cell.imageView!.image = coordinateImage
        })
    }
    
    // MARK - UICollectionView
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        let sectionCount = self.fetchedResultsController.sections?.count ?? 0
        
        println("Section count: \(sectionCount)")
        return sectionCount
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        
        println("Number of Cells from collection view number of items in section: \(sectionInfo.numberOfObjects)")
        
        return sectionInfo.numberOfObjects
        
//        let totalCells = PinPhotos.sharedInstance().pageLimit
//        println("Total Cells: \(PinPhotos.sharedInstance().pageLimit)")
//        
//        if sectionInfo.numberOfObjects > 0 {
//            return sectionInfo.numberOfObjects
//        } else {
//            return totalCells
//        }
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! TaskCancellingCollectionViewCell
        cell.activityIndicator.stopAnimating()
        cell.backgroundColor = UIColor.blackColor()
        cell.activityIndicator.startAnimating()
        
//        if self.fetchedResultsController.fetchedObjects!.count < PinPhotos.sharedInstance().pageLimit {
//            fetchPhoto()
//        }
        //fetchPhoto()
        
        println("CELL for item at index path: \(indexPath)")
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
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
        
        
        
        self.pinAlertViewController(photo)
//        sharedContext.deleteObject(photo)
//        CoreDataStackManager.sharedInstance().saveContext()
//        
        //collectionView.reloadData()
    }
    
    
    // MARK: - Fetched Results Controller Delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        // Try using just Inserted array
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()

    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
        println("Did change section.")
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
        
        //println("Controller did change object; Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
        
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
            updatedIndexPaths.append(newIndexPath!)
            break
        case .Move:
            println("Moving an item. We don't expect to see this in this app.")
            break
        default:
            break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        println("HEY!!! in controllerDidChangeContent. changes.count: \(insertedIndexPaths.count + deletedIndexPaths.count)")
        CoreDataStackManager.sharedInstance().saveContext()
        
        self.collectionView.performBatchUpdates({() -> Void in
            
            println("Inserting items at index paths")
            self.collectionView.insertItemsAtIndexPaths(self.insertedIndexPaths)
            
            //for indexPath in self.deletedIndexPaths {
            println("Deleting items at index paths")
            self.collectionView.deleteItemsAtIndexPaths(self.deletedIndexPaths)
            //}
            
            return
            }, completion: { completed in
                if completed {
                    
                    
                    //for indexPath in self.updatedIndexPaths {
                    println("Reloading items at index paths")
                    self.collectionView.reloadItemsAtIndexPaths(self.updatedIndexPaths)
                    //}
                    println("Batch update completed")
                    println("Controller did change content; Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
                }
        })
        
    }
    
    // MARK - Misc Activities
    
    // Use UIAlertController to inform user of issue.
    func alertUser() {
        dispatch_async(dispatch_get_main_queue(), {
            let alertController = UIAlertController(title: "Problem", message: self.alertMessage, preferredStyle: .Alert)
            
            if let message = self.alertMessage {
                alertController.message = message
            }
            
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) -> Void in
                self.dismissViewControllerAnimated(true, completion: nil)
            }
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    
    func pinAlertViewController(photo: Photo) {
        let pinController = UIAlertController(title: "Pin Actions", message: "Select an Action for this Pin.", preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        pinController.addAction(UIAlertAction(title: "Remove This Photo from Album", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
            println("Removing Photo")
            photo.photoImage = nil
            self.removePhoto(photo)
            return
        }))
        
        pinController.addAction(UIAlertAction(title: "Delete This Pin", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
            println("Deleting Pin")
            //self.delegate?.removeAnnotation(self, withPin: self.pin)
            
            PinPhotos.sharedInstance().deletePin(self.pin!)
            
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.navigationController!.popToRootViewControllerAnimated(true)
            }
        }))
        
        pinController.addAction(UIAlertAction(title: "Delete All Pins", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
            println("Deleting All Pins")
            PinPhotos.sharedInstance().deleteAllPins()
            
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.navigationController!.popToRootViewControllerAnimated(true)
            }
        }))
        
        pinController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: { (action: UIAlertAction!) -> Void in
            println("Canceling Pin Action")
            return
        }))
        
        presentViewController(pinController, animated: true, completion: nil)
    }
    
    func removePhoto(photo: Photo) {
        photo.pin = nil
        sharedContext.deleteObject(photo)
        var error: NSError? = nil
        
        if !sharedContext.save(&error) {
            
            // Use UIAlertController to inform user of issue.
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        //collectionView.deleteItemsAtIndexPaths(selectedIndexes)
        
        // Reload the table on the main thread
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionView!.reloadData()
        }
    }
    
    
}