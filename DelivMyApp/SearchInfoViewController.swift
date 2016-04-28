//
//  SearchInfoViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 4/20/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import MapKit

class SearchInfoViewController: UITableViewController, NSFetchedResultsControllerDelegate, MKMapViewDelegate {
    
    var searchInfo: Request!
    var distanceInfo: String!
    
    var shared = SharedView()
    
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var placeNameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var DelivStatusLabel: UILabel!
    @IBOutlet weak var DeliveryAtLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var itemsLabel: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var requestInfoLabel: UILabel!
    @IBOutlet weak var createdAtLabel: UILabel!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var acceptDelivBtn: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Perform the fetch
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("error")
        }
        
        // Set the delegate to this view controller
        
        fetchedResultsController.delegate = self
        
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        mapView.delegate = self
        
        loadLabels()
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Request")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "id == %@", self.searchInfo.id);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: self.sharedContext,
                                                                  sectionNameKeyPath: nil,
                                                                  cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
    // Set Map
    
    func setMap(pin: Location){
        
        mapView.addAnnotation(pin)
        
        //Set a region
        
        let span = MKCoordinateSpanMake(0.005, 0.005)
        let region = MKCoordinateRegion(center: pin.coordinate, span: span)
        mapView.setRegion(region, animated: false)
        
        // Disable Zoom, scroll and user interaction.
        
        mapView.zoomEnabled = false
        mapView.scrollEnabled = false
        mapView.userInteractionEnabled = false
    }
    
    @IBAction func cancelRequest(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    // Accept action
    
    @IBAction func acceptDelivAction(sender: AnyObject) {
        overwriteAlert()
    }
    
    func submitRequest(alert: UIAlertAction!) -> Void {
        
        // enable newtwork indicator
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        let body = [
            DelivMyClient.ParameterKeys.RequestID :  searchInfo.id
        ]
        
        let method = DelivMyClient.Methods.DeliversNew
        
        DelivMyClient.sharedInstance().postRequest(body, paramKey: method) { (success, result, error) in
            if success {
                
                // Remove accepted request from search list
                
                self.removeRequests()
                
                // return to search list
                
                self.deliverAccAlert()
                
                // disable newtwork indicator
                
                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    if let error: String = error!.localizedDescription {
                        self.shared.AlertMessage(error, viewControl: self)
                    }
                })
            }
        }
    }
    
    func overwriteAlert(){
        let msg = "Are you sure?"
        let alert = UIAlertController(title: "", message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.Default, handler: submitRequest))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true,completion:nil)
    }
    
    func deliverAccAlert(){
        let msg = "This request #\(self.title!) assigned to you, for more details please check 'MyDeliv' Tab! deliver time \(self.DeliveryAtLabel.text!)"
        let alert = UIAlertController(title: "", message: msg, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { alert -> Void in
           self.dismissViewControllerAnimated(true, completion: nil)
    }))
        self.presentViewController(alert, animated: true,completion:nil)
    }
    
    // Remove existing Requests
    
    func removeRequests() -> Void {
        for request in self.fetchedResultsController.fetchedObjects as! [Request] {
            dispatch_async(dispatch_get_main_queue()) {
                self.sharedContext.deleteObject(request)
            }
        }
    }
    
    // Load Label info
    
    func loadLabels() -> Void {
        // Title
        
        self.title = "Request #\(searchInfo.id)"
        
        // Labels
        
        placeNameLabel.text = searchInfo.placename
        categoryLabel.text = "\(searchInfo.category_name)"
        DeliveryAtLabel.text = searchInfo.delivery_at.offsetFrom(NSDate())
        createdAtLabel.text = "Placed On \(searchInfo.created_at.formatted)"
        itemsLabel.text = "Total Items \(searchInfo.items_count)"
        
        // Status
        
        let statuses = Status(status: searchInfo.status_id)
        DelivStatusLabel.text = "Status: \(statuses.getStatus())"
        
        // Load Location
        if searchInfo.location == nil {
            
        } else {
            dispatch_async(dispatch_get_main_queue()) {
                self.addressLabel.text = self.searchInfo.location?.address
                self.setMap(self.searchInfo.location!)
            }
        }
        
        distance.text = distanceInfo
        
        // load image
        if (searchInfo.profile != nil) {
            
            if let requestLab = searchInfo.profile {
                requestInfoLabel.text = "\(requestLab.first_name) \(requestLab.last_name)"
            }
            
            if let localImage = searchInfo.profile!.userImage {
                userImage.image = localImage
            } else if searchInfo.profile?.picture == nil || searchInfo.profile?.picture == "" {
                userImage.image = UIImage(named: "UserImage")
            }
                
                // If the above cases don't work, then we should download the image
                
            else {
                
                // Set the placeholder
                userImage.image = UIImage(named: "UserImage")
                
                
                DelivMyClient.sharedInstance().taskForImageWithSize(searchInfo.profile!.picture!) { (imageData, error) -> Void in
                    
                    if let data = imageData {
                        dispatch_async(dispatch_get_main_queue()) {
                            let image = UIImage(data: data)
                            self.searchInfo.profile!.userImage = image
                            self.userImage.image = image
                        }
                    }
                }
            }
        } else {
            requestInfoLabel.text = "None"
        }
        
        userImage.layer.cornerRadius = userImage.frame.size.width / 2
        userImage.clipsToBounds = true
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let section = indexPath.section
        if (section == 2) {
            let controller =
                storyboard!.instantiateViewControllerWithIdentifier("RequestItemsViewController")
                    as! RequestItemsViewController
            
            // Similar to the method above
            
            controller.requestInfoItems = self.searchInfo
            
            self.presentViewController(controller, animated: true,completion:nil)
        }
        
    }
}
