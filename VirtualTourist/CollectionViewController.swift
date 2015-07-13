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
    var photos = [Photo]()
    
    var searchTask: NSURLSessionDataTask?
    
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
        
        // Cancel the last task
        if let task = searchTask {
            task.cancel()
        }
        
        println("Deleting photos")
        let fetched = fetchedResultsController.fetchedObjects
        
        fetched?.map() {
            self.sharedContext.deleteObject($0 as! NSManagedObject)
        }
        
        var error: NSError? = nil
        
        if !sharedContext.save(&error) {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        
        CoreDataStackManager.sharedInstance().saveContext()
        
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.navigationController?.popToRootViewControllerAnimated(true)
        }
    }
    
    @IBAction func fetchNewCollection(sender: AnyObject) {
        // Cancel the last task
        if let task = searchTask {
            task.cancel()
        }
        
        println("Deleting photos")
        let fetched = fetchedResultsController.fetchedObjects
        
        fetched?.map() {photo in
            self.sharedContext.deleteObject(photo as! Photo)
        }
        
        var error: NSError? = nil
        
        if !sharedContext.save(&error) {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        
        let methodArguments = [
            "method": PinPhotos.API.METHOD_NAME,
            "api_key": PinPhotos.API.API_KEY,
            "bbox": PinPhotos.sharedInstance().createBoundingBoxString(pin!),
            "safe_search": PinPhotos.API.SAFE_SEARCH,
            "extras": PinPhotos.API.EXTRAS,
            "format": PinPhotos.API.DATA_FORMAT,
            "nojsoncallback": PinPhotos.API.NO_JSON_CALLBACK
        ]
        
        searchTask = PinPhotos.sharedInstance().taskForResource(methodArguments, completionHandler: { (parsedResult, error) -> Void in
            
            // Handle the error case
            if let error = error {
                self.alertMessage = "Error searching for photos: \(error.localizedDescription)"
                println(self.alertMessage)
                return
            }
            
            if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                println("Got some photos")
                if let totalPages = photosDictionary["pages"] as? Int {
                    println("Counting pages")
                    // this seems odd; why limit of 40?
                    let pageLimit = min(totalPages, 40)
                    let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
                    
                    var withPageDictionary: [String:AnyObject] = methodArguments
                    withPageDictionary["page"] = "\(randomPage)"
                    
                    PinPhotos.sharedInstance().taskForResource(withPageDictionary, completionHandler: { (parsedResult, error) -> Void in
                        // Handle the error case
                        if let error = error {
                            self.alertMessage = "Error searching for photos: \(error.localizedDescription)"
                            println(self.alertMessage)
                            return
                        }
                        
                        var totalPhotosValue = 0
                        if let totalPhotos = photosDictionary["total"] as? String {
                            totalPhotosValue = (totalPhotos as NSString).integerValue
                        }
                        
                        if totalPhotosValue > 0 {
                            
                            println("Total photos: \(totalPhotosValue)")
                            if let photosArray = photosDictionary["photo"] as? [[String:AnyObject]] {
                                println("Creating array of Photo entities")
                                self.photos = photosArray.map() {
                                    Photo(dictionary: $0, context: self.sharedContext)
                                }
                                
                                CoreDataStackManager.sharedInstance().saveContext()
                            }
                        }
                    })
                } else {
                    self.alertMessage = "Can't find key 'pages' in \(photosDictionary)"
                    println(self.alertMessage)
                }
            } else {
                self.alertMessage = "Can't find key 'photos' in \(parsedResult)"
                println(self.alertMessage)
            }
        })
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
        
        println("Photos in fetched objects: \(fetchedResultsController.fetchedObjects!.count)")
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
        println("Photos in fetched objects 2: \(fetchedResultsController.fetchedObjects!.count)")
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
        cell.activityIndicator.startAnimating()
        var coordintateImage = UIImage(named: "posterPlaceHoldr")
        
        cell.imageView!.image = nil
        
        // Set the Photo Image
        if photo.imagePath == nil || photo.imagePath == "" {
            coordintateImage = UIImage(named: "noImage")
        } else if photo.photoImage != nil {
            coordintateImage = photo.photoImage
        } else {
            // find out what goes here, if anything. like favorite actors?
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
        
        self.pinAlertViewController(photo)
        //configureCell(cell, photo: photo)
        
//        collectionView.deleteItemsAtIndexPaths(selectedIndexes)
//        sharedContext.deleteObject(photo)
//        CoreDataStackManager.sharedInstance().saveContext()
//        
//        collectionView.reloadData()
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
            return
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
    
    
    func pinAlertViewController(photo: Photo) {
        let pinController = UIAlertController(title: "Pin Actions", message: "Select an Action for this Pin.", preferredStyle: UIAlertControllerStyle.ActionSheet)
        
        pinController.addAction(UIAlertAction(title: "Remove This Photo from Album", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
            println("Removing Photo")
            self.removePhoto(photo)
            return
        }))
        
        pinController.addAction(UIAlertAction(title: "Delete This Pin", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
            println("Deleting Pin")
            self.deletePin(self.pin!)
            
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.navigationController?.popToRootViewControllerAnimated(true)
            }
        }))
        
        pinController.addAction(UIAlertAction(title: "Delete All Pins", style: .Destructive, handler: { (action: UIAlertAction!) -> Void in
            println("Deleting All Pins")
            self.deleteAllPins()
            
            NSOperationQueue.mainQueue().addOperationWithBlock {
                self.navigationController?.popToRootViewControllerAnimated(true)
            }
        }))
        
        pinController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: { (action: UIAlertAction!) -> Void in
            println("Canceling Pin Action")
            return
        }))
        
        presentViewController(pinController, animated: true, completion: nil)
    }
    
    func removePhoto(photo: Photo) {
        collectionView.deleteItemsAtIndexPaths(selectedIndexes)
        sharedContext.deleteObject(photo)
        var error: NSError? = nil
        
        if !sharedContext.save(&error) {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
        
        CoreDataStackManager.sharedInstance().saveContext()
        
        collectionView.reloadData()
    }
    
    func deletePin(pin: Pin) {
        println("Deleting a pin")
        
        sharedContext.deleteObject(pin)
        var error: NSError? = nil
        
        if !sharedContext.save(&error) {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
    }
    
    func deleteAllPins() {
        println("Deleting pins")
        let fetched = fetchedResultsController.fetchedObjects
        
        fetched?.map() {
            self.sharedContext.deleteObject($0 as! NSManagedObject)
        }
        
        var error: NSError? = nil
        
        if !sharedContext.save(&error) {
            alertMessage = "Error performing initial fetch: \(error)"
            
            println(alertMessage)
            alertUser()
        }
    }
    
    
}