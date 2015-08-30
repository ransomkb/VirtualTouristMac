//
//  MapVCExtension.swift
//  VirtualTourist
//
//  Created by Ransom Barber on 6/29/15.
//  Copyright (c) 2015 Ransom Barber. All rights reserved.
//

import Foundation
import MapKit

// Convenience extension for map view delegate functions.
extension MapViewController: MKMapViewDelegate {
    
    // Set up the annotations on the map view using Pin data.
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        
        // Ensure can make a Pin based annotation.
        if let annotation = annotation as? Pin {
            
            let identifier = "pin"
            var view: MKPinAnnotationView
            
            // Check if there is an unused annotation available in the queue.
            if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier) as? MKPinAnnotationView {
                
                // Set the annotation of the dequeued view
                dequeuedView.annotation = annotation
                view = dequeuedView
            } else {
                
                // Create a new pin annotation view with an identifier of pin.
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                
                // Make call out bubble visible.
                view.canShowCallout = true
                
                // Place the call out bubble nearby.
                view.calloutOffset = CGPoint(x: -5, y: 5)
                
                // Add a Detail Disclosure type of accessory view to right side of the call out.
                view.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIView
                
                //IMPORTANT: DON'T NEED TO DRAG IT.
                //view.draggable = true
            }
            
            // Animate the pin dropping in.
            view.animatesDrop = true
            return view
        }
        
        // Return nil as cannot make a Pin based annotation.
        return nil
    }
    
    // Handle the tapping of the call out accessory control for map view.
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        
        // Create a pin from the specific Pin of the annotation view.
        let pin = view.annotation as! Pin
        
        // Create an instance of CollectionViewController on storyboard.
        let controller = self.storyboard!.instantiateViewControllerWithIdentifier("CollectionViewController") as! CollectionViewController
        
        // Set the collection view pin to the annotation pin.
        controller.pin = pin
        println("Callout accessory tapped.")
        println("Before Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
        
        // Make sure zoom data is saved before segue.
        self.saveRegion()
        
        // Set the zoom span for the collection view map as well.
        controller.regionSpan = self.regionSpan
        println("Later Region Span Lat: \(self.regionSpan?.latitudeDelta), Lon: \(self.regionSpan?.longitudeDelta)")
        
        // Push collection view controller onto main queue.
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.navigationController!.pushViewController(controller, animated: true)
        }
    }
}
