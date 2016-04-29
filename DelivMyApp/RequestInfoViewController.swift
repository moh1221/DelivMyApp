//
//  RequestInfoViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/29/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class RequestInfoViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    var requestInfo: Request!
    var shared = SharedView()
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var placeNameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var DelivStatusLabel: UILabel!
    @IBOutlet weak var DeliveryAtLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var itemsLabel: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var delivInfoLabel: UILabel!
    @IBOutlet weak var receriptLabel: UILabel!
    @IBOutlet weak var createdAtLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        self.locIndicator.alpha = 0
        
        loadLabels()
        
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
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
    
    // load location info for Request
    
    func loadLocationInfo(){
        
        // Enable Indicator
        
        self.locIndicator.showIndicator(true)
        
        let parameters = [ "id": requestInfo.id]
        let method = DelivMyClient.Methods.RequestsLocations
        DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
            if let error = error {
                
                self.shared.AlertMessage(error.localizedDescription, viewControl: self)
                
                // disable Indicator
                
                self.locIndicator.showIndicator(false)
                
            } else {
                
                if let locationDictionaries = JSONResult as? [String : AnyObject] {
                    // Update the table on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                    
                        let location = Location(dictionary: locationDictionaries, context: self.sharedContext)
                        location.request = self.requestInfo
                        CoreDataStackManager.sharedInstance().saveContext()
                    
                        self.addressLabel.text = self.requestInfo.location?.address
                        self.setMap(self.requestInfo.location!)
                        // diable Indicator
                        
                        self.locIndicator.showIndicator(false)
                    }
                } else {
                    let error = NSError(domain: "Cant find request in \(JSONResult)", code: 0, userInfo: nil)
                    print(error)
                    // disable Indicator
                    
                    self.locIndicator.showIndicator(false)
                }
            }
        }
    }
    
    func loadLabels() -> Void {
        
        // Title
        
        self.title = "Request \(requestInfo.id)"
        
        // Labels
        placeNameLabel.text = requestInfo.placename
        categoryLabel.text = "\(requestInfo.category_name)"
        DeliveryAtLabel.text = requestInfo.delivery_at.offsetFrom(NSDate())
        createdAtLabel.text = "Placed On \(requestInfo.created_at.formatted)"
        itemsLabel.text = "Total Items \(requestInfo.items_count)"
        
        // Status
        
        let statuses = Status(status: requestInfo.status_id)
        DelivStatusLabel.text = "Status: \(statuses.getStatus())"
        
        // Load Location
        if requestInfo.location == nil {
            loadLocationInfo()
        } else {
            dispatch_async(dispatch_get_main_queue()) {
                self.addressLabel.text = self.requestInfo.location?.address
                self.setMap(self.requestInfo.location!)
            }
        }
        
        // load image
        if (requestInfo.deliver != nil) {
            
            if let deliverLab = requestInfo.deliver!.profile {
                delivInfoLabel.text = "\(deliverLab.first_name) \(deliverLab.last_name)"
            }
            
            if (requestInfo.deliver!.receipt_img != nil){
                receriptLabel.text = "View Receipt Image"
            } else {
                receriptLabel.text = "None"
            }
            
            if let localImage = requestInfo.deliver!.profile!.userImage {
                userImage.image = localImage
            } else if requestInfo.deliver!.profile?.picture == nil || requestInfo.deliver!.profile?.picture == "" {
                userImage.image = UIImage(named: "UserImage")
            }
                
                // If the above cases don't work, then we should download the image
                
            else {
                
                // Set the placeholder
                userImage.image = UIImage(named: "UserImage")
                
                
                DelivMyClient.sharedInstance().taskForImageWithSize(requestInfo.deliver!.profile!.picture!) { (imageData, error) -> Void in
                    
                    if let data = imageData {
                        dispatch_async(dispatch_get_main_queue()) {
                            let image = UIImage(data: data)
                            self.requestInfo.deliver!.profile!.userImage = image
                            self.userImage.image = image
                        }
                    }
                }
            }
        } else {
            delivInfoLabel.text = "None"
            receriptLabel.text = "None"
        }
        
        userImage.layer.cornerRadius = userImage.frame.size.width / 2
        userImage.clipsToBounds = true
    }
    
}

extension RequestInfoViewController {
    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let section = indexPath.section
        
        switch section {
            
        case 2:
            cell.accessoryType = self.delivInfoLabel.text != "None" ? .Checkmark : .None
            cell.selectionStyle = UITableViewCellSelectionStyle.None
            
            
        case 3:
            cell.accessoryType = self.receriptLabel.text != "None" ? .DisclosureIndicator : .None
            cell.selectionStyle = self.receriptLabel.text != "None" ? .Default : .None
        default: break
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let section = indexPath.section
        if (section == 1) {
            let controller =
                storyboard!.instantiateViewControllerWithIdentifier("RequestItemsViewController")
                    as! RequestItemsViewController
            
            // Similar to the method above
            
            controller.requestInfoItems = self.requestInfo
            
            self.presentViewController(controller, animated: true,completion:nil)
        }
        
    }

}
