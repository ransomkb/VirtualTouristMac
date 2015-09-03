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
    
    // Store zoom data
    var coordinate: CLLocationCoordinate2D?
    var regionSpan: MKCoordinateSpan?
    
    var alertMessage: String?
    
    // Pin for this collection
    var pin: Pin!
    var photos = [Photo]()
    
    // For canceling session data task quickly
    var searchTask: NSURLSessionDataTask?
    
    var sharedContext: NSManagedObjectContext = CoreDataStackManager.sharedInstance().managedObjectContext!
    
    // Computed property for zooming
    var region: MKCoordinateRegion {
        return MKCoordinateRegionMake(coordinate!, regionSpan!)
    }
    
    // IMPORTANT: May not need this
    // Computed property pointing to the directory of the zoom data: zoomDictionary
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        return url.URLByAppendingPathComponent("zoomDictionary").path!
    }
    
    // Lazily computed property pointing to the Photo entity objects, sorted by title, predicated on the pin.
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        //return PinPhotos.sharedInstance().photoFetchedResultsController
        
        // Create a fetch request for Photo objects.
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        // Sort the fetch request by title, ascending.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        // Limit the fetch request to just those photos related to the Pin.
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin)
        
        // Create the fetched results controller.
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    // Pop to root controller
    @IBAction func backToMap(sender: AnyObject) {
        
        // Cancel the most recent task if running.
        if let task = searchTask {
            task.cancel()
        }
        
        // Pop down to the root navigation controller via main queue.
        popToRootController()
    }
    
    // Cancel all activities and Pop to root controller.
    func cancelActivities() {
        
        // Cancel the last task
        if let task = searchTask {
            task.cancel()
        }
        
        println("Canceled: Deleting photos")
        
        // Delete photos related to the Pin.
        PinPhotos.sharedInstance().deletePhotosForPin(self.pin!)
        
        // Pop down to the root navigation controller via main queue.
        popToRootController()
    }
    
    // Fetch a new collection of photos from Flickr at the location of the Pin.
    @IBAction func fetchNewCollection(sender: AnyObject) {
        println("Fetch new collection tapped")
        
        // Cancel the most recent task if running.
        if let task = searchTask {
            task.cancel()
        }
        
        println("NewCollection: Deleting photos")
        
        // Delete all photos related to this Pin.
        PinPhotos.sharedInstance().deletePhotosForPin(self.pin!)
        
        // Save the changes.
        CoreDataStackManager.sharedInstance().saveContext()
        
        // Fetch all pages of photos on Flickr at the location of this Pin in order to get a page count.
        // Fetch all photos for a randomly chosen page.
        fetchTotalPages()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        println("Collection View did load.")
        
        // Ensure there is a pin.
        if let pin = pin {
            println("Collection Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
            
            // Compute the coordinate property.
            coordinate = pin.coordinate
        } else {
            // There is no Pin.
            // Cancel all activities and Pop to root controller.
            cancelActivities()
        }
        
        // Start the fetched results controller
        var error: NSError?
        fetchedResultsController.performFetch(&error)
        
        // Handle an error.
        if let error = error {
            
            // Use UIAlertController to inform user of issue.
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        
        // Set self as delegate for map view and fetch results controller.
        fetchedResultsController.delegate = self
        mapView.delegate = self
        
        println("View  did load. Photos in fetched objects: \(fetchedResultsController.fetchedObjects!.count)")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        println("Collection View will appear")
        
        // Set the region to be shown in the map view.
        mapView.setRegion(region, animated: true)
        
        // Add a Pin annotation to the map view.
        mapView.addAnnotation(pin)
        
        // Check if Pin has photos already.
        if pin.photos.isEmpty {
            
            // Hide the New Collection button as no collection yet, so we will fetch one automatically.
            newCollectionButton.hidden = true
            println("pin.photos is empty")
            
            // Fetch all pages of photos on Flickr at the location of this Pin in order to get a page count.
            // Fetch all photos for a randomly chosen page.
            fetchTotalPages()
        }
        
        println("View will appear. Photos in fetched objects: \(fetchedResultsController.fetchedObjects!.count)")
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check if Pin has photos already.
//        if pin.photos.isEmpty {
//            
//            // Hide the New Collection button as no collection yet, so we will fetch one automatically.
//            newCollectionButton.hidden = true
//            println("pin.photos is empty")
//            
//            // Fetch all pages of photos on Flickr at the location of this Pin in order to get a page count.
//            fetchTotalPages()
//        }
        
        println("View did appear. Photos in fetched objects after getting album: \(self.fetchedResultsController.fetchedObjects!.count)")
    }
    
    // Pop down to the root navigation controller via main queue.
    func popToRootController() {
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.navigationController!.popToRootViewControllerAnimated(true)
        }
    }
    
    // Fetch all pages of photos on Flickr at the location of this Pin in order to get a page count.
    // Fetch all photos for a randomly chosen page.
    func fetchTotalPages() {
        
        println("Fetching Total Pages")
        
        // Use a completion handler to show success of getting a total page count.
        PinPhotos.sharedInstance().getTotalPhotos(self, pin: pin) { (success, errorString) -> Void in
            if success {
                println("Did Set Total pages: \(PinPhotos.sharedInstance().totalPages)")
                
                // Get all the photos on a randomly chosen page.
                self.fetchPhotos()
            } else {
                // Report failure.
                // Use UIAlertController to inform user of issue.
                self.alertMessage = errorString
                self.alertUser()
            }
        }

    }
    
    // Get all the photos on a randomly chosen page.
    func fetchPhotos() {
        
        // Get the photos on Flickr for a Pin, using its longitude and latitude, to be used in an album.
        // Report success with a completion handler.
        PinPhotos.sharedInstance().getPhotosForAlbum(self, pin: self.pin) { (success, errorString) -> Void in
            
            // Check completion handler for success.
            if success {
                println("Getting album photo succeeded. Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
                
                // Save the changes.
                CoreDataStackManager.sharedInstance().saveContext()
                
                // Reveal the New Collection button.
                self.newCollectionButton.hidden = false
            } else {
                // Report failure.
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
        
        dispatch_async(dispatch_get_main_queue(), {
            cell.backgroundColor = UIColor.blackColor()
            cell.activityIndicator.startAnimating()
        })
        
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
            println("Photo has an image name, but it has not been downloaded yet.")
            
            println(photo.imagePath)
            let imageURL = NSURL(string: photo.imagePath!)
            
            if let imageData = NSData(contentsOfURL: imageURL!) {
                
                photo.photoImage = UIImage(data: imageData)
                coordinateImage = photo.photoImage
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            
            cell.imageView!.image = coordinateImage
            
            cell.activityIndicator.stopAnimating()
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
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        // Create a photo from the fetched results controller object at the index path.
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        // Create a cell from the identifier.
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! TaskCancellingCollectionViewCell
        
        println("CELL for item at index path: \(indexPath)")
        
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
        
        // Remove the photo from the shared context; set image at image path to nil.
        removePhoto(photo)
        
        //self.pinAlertViewController(photo)
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
            
            // Insert items at inserted indexPaths.
            self.collectionView.insertItemsAtIndexPaths(self.insertedIndexPaths)
            
            println("Deleting items at index paths")
            
            // Delete items at deletedIndexPaths.
            self.collectionView.deleteItemsAtIndexPaths(self.deletedIndexPaths)
            return
            }, completion: { completed in
                if completed {
                    println("Reloading items at index paths")
                    
                    // Reload updated indexpaths.
                    self.collectionView.reloadItemsAtIndexPaths(self.updatedIndexPaths)
                    
                    println("Batch update completed")
                    println("Controller did change content; Photos in fetched objects: \(self.fetchedResultsController.fetchedObjects!.count)")
                }
        })
        
    }
    
    // MARK - Misc Activities
    
    // Use UIAlertController to inform user of issue.
    func alertUser() {
        
        // Use the main queue for speed.
        dispatch_async(dispatch_get_main_queue(), {
            
            // Create a UIAlertController titled Problem.
            let alertController = UIAlertController(title: "Problem", message: self.alertMessage, preferredStyle: .Alert)
            
            // Pass existing message to alert controller.
            if let message = self.alertMessage {
                alertController.message = message
            }
            
            // Create an OK action button.
            let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { (action) -> Void in
                
            }
            
            // Add OK button to alert controller.
            alertController.addAction(okAction)
            
            // Present the alert controller.
            self.presentViewController(alertController, animated: true, completion: nil)
        })
    }
    
    
//    func pinAlertViewController(photo: Photo) {
//        let pinController = UIAlertController(title: "Pin Actions", message: "Select an Action for this Pin.", preferredStyle: UIAlertControllerStyle.ActionSheet)
//        
//        pinController.addAction(UIAlertAction(title: "Remove This Photo from Album", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
//            println("Removing Photo")
//            photo.photoImage = nil
//            self.removePhoto(photo)
//            return
//        }))
//        
//        pinController.addAction(UIAlertAction(title: "Delete This Pin", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
//            println("Deleting Pin")
//            //self.delegate?.removeAnnotation(self, withPin: self.pin)
//            
//            PinPhotos.sharedInstance().deletePin(self.pin!)
//            
//            NSOperationQueue.mainQueue().addOperationWithBlock {
//                self.navigationController!.popToRootViewControllerAnimated(true)
//            }
//        }))
//        
//        pinController.addAction(UIAlertAction(title: "Delete All Pins", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
//            println("Deleting All Pins")
//            PinPhotos.sharedInstance().deleteAllPins()
//            
//            NSOperationQueue.mainQueue().addOperationWithBlock {
//                self.navigationController!.popToRootViewControllerAnimated(true)
//            }
//        }))
//        
//        pinController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: { (action: UIAlertAction!) -> Void in
//            println("Canceling Pin Action")
//            return
//        }))
//        
//        presentViewController(pinController, animated: true, completion: nil)
//    }
    
    // Remove the photo from the shared context; set image path to nil.
    func removePhoto(photo: Photo) {
        
        // Create error variable.
        var error: NSError? = nil

        // if deting photo, pin will be notified.
        // photo.pin = nil
        
        // Remove the photo from the directory by setting the image to nil at the image path.
        photo.photoImage = nil
        
        // Delete the photo from the shared context.
        sharedContext.deleteObject(photo)
        
        // Check for error.
        if !sharedContext.save(&error) {
            
            // Use UIAlertController to inform user of issue.
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
    }
    
    
}