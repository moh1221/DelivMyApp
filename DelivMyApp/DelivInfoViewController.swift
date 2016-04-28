//
//  DelivInfoViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 4/2/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class DelivInfoViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    var deliverInfo: Deliver!
    var shared = SharedView()
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var placeNameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var DelivStatusLabel: UILabel!
    @IBOutlet weak var DeliveryAtLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var itemsLabel: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var requesterInfo: UILabel!
    @IBOutlet weak var receriptLabel: UILabel!
    @IBOutlet weak var createdAtLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        loadLabels()
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // load location info for Request
    
    func loadLocationInfo(){
        let parameters = [ "id": deliverInfo.request!.id]
        let method = DelivMyClient.Methods.RequestsLocations
        
        DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
            if let error = error {
                
                self.shared.AlertMessage(error.localizedDescription, viewControl: self)
                
            } else {
                
                if let locationDictionaries = JSONResult as? [String : AnyObject] {
                    
                    dispatch_async(dispatch_get_main_queue()) {
                    
                        let location = Location(dictionary: locationDictionaries, context: self.sharedContext)
                        location.request = self.deliverInfo.request
                        CoreDataStackManager.sharedInstance().saveContext()
                        // Update the table on the main thread
                    
                        self.addressLabel.text = self.deliverInfo.request!.location?.address
                        self.setMap(self.deliverInfo.request!.location!)
                    }
                } else {
                    let error = NSError(domain: "Cant find request in \(JSONResult)", code: 0, userInfo: nil)
                    print(error)
                }
            }
        }
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
    
    // Load Labels info
    
    func loadLabels() -> Void {
        
        self.title = "Request \(deliverInfo.request!.id)"
        
        // Labels
        placeNameLabel.text = deliverInfo.request!.placename
        categoryLabel.text = "\(deliverInfo.request!.category_name)"
        DeliveryAtLabel.text = deliverInfo.request!.delivery_at.offsetFrom(NSDate())
        
        createdAtLabel.text = "Placed On \(deliverInfo.request!.created_at.formatted)"
        itemsLabel.text = "Total Items \(deliverInfo.request!.items_count)"
        
        // Status
        let statuses = Status(status: deliverInfo.request!.status_id)
        DelivStatusLabel.text = "Status: \(statuses.getStatus())"
        
        // Load Location
        if deliverInfo.request!.location == nil {
            loadLocationInfo()
        } else {
            dispatch_async(dispatch_get_main_queue()) {
                self.addressLabel.text = self.deliverInfo.request!.location?.address
                self.setMap(self.deliverInfo.request!.location!)
            }
        }

    }
}

extension DelivInfoViewController {
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let section = indexPath.section
        if (section == 1) {
            let controller =
                storyboard!.instantiateViewControllerWithIdentifier("RequestItemsViewController")
                    as! RequestItemsViewController
            
            // Similar to the method above
            
            controller.requestInfoItems = self.deliverInfo.request
            
            self.presentViewController(controller, animated: true,completion:nil)
        }
        
    }

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        let section = indexPath.section
        
        switch section {
        case 2:
            cell.accessoryType = requesterInfo.text != "None" ? .Checkmark : .None
            cell.selectionStyle = UITableViewCellSelectionStyle.None
        case 3:
            cell.accessoryType = receriptLabel.text != "None" ? .DisclosureIndicator : .None
            cell.selectionStyle = receriptLabel.text != "None" ? .Default : .None
        default: break
        }
    }
}
