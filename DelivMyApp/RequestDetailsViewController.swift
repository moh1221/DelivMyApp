//
//  RequestDetailsViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/25/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import MapKit
import UIKit
import CoreData

class RequestDetailsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    
    var requestInfo: Request!
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var deliveryLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // Perform the fetch
        do {
            try fetchedResultsController.performFetch()
        } catch {
            
        }
        
        // Set the delegate to this view controller
        fetchedResultsController.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // load direct info
        placeLabel.text = requestInfo.placename
        categoryLabel.text = "Category: \(requestInfo.category_id)"
        deliveryLabel.text = requestInfo.delivery_at.offsetFrom(NSDate())
        statusLabel.text = "Status: \(requestInfo.status_id)"
        
        if requestInfo.items.isEmpty {
            let parameters = [ "id": requestInfo.id]
            let method = DelivMyClient.Methods.RequestsItems
            DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
                if let error = error {
                    print(error)
                } else {
                    
                    if let itemsDictionaries = JSONResult as? [[String : AnyObject]] {
                        // Update the table on the main thread
                        dispatch_async(dispatch_get_main_queue()) {
                            // Parse the array of movies dictionaries
                            let _ = itemsDictionaries.map() { (dictionary: [String : AnyObject]) -> Item in
                            
                                let item = Item(dictionary: dictionary, context: self.sharedContext)
                                item.request = self.requestInfo
                                print(dictionary)
                                return item
                            
                            }
                        
                        
                            CoreDataStackManager.sharedInstance().saveContext()
                            self.tableView.reloadData()
                        }
                    } else {
                        let error = NSError(domain: "Cant find request in \(JSONResult)", code: 0, userInfo: nil)
                        print(error)
                    }
                }
            }
        }
        if requestInfo.location == nil {
            let parameters = [ "id": requestInfo.id]
            let method = DelivMyClient.Methods.RequestsLocations
            DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
                if let error = error {
                    print(error)
                } else {
                    
                    if let locationDictionaries = JSONResult as? [String : AnyObject] {
                        // Update the table on the main thread
                        dispatch_async(dispatch_get_main_queue()) {
                      
                            let location = Location(dictionary: locationDictionaries, context: self.sharedContext)
                            location.request = self.requestInfo
                            
                            CoreDataStackManager.sharedInstance().saveContext()
                        
                            self.addressLabel.text = self.requestInfo.location?.address
                            self.setMap(self.requestInfo.location!)
                        }
                    } else {
                        let error = NSError(domain: "Cant find request in \(JSONResult)", code: 0, userInfo: nil)
                        print(error)
                    }
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue()) {
                self.addressLabel.text = self.requestInfo.location?.address
                self.setMap(self.requestInfo.location!)
            }
        }
    }
    
    // Set Map
    func setMap(pin: Location){
        
        mapView.addAnnotation(pin)
        
        //Set a region
        
        let span = MKCoordinateSpanMake(0.03, 0.03)
        let region = MKCoordinateRegion(center: pin.coordinate, span: span)
        mapView.setRegion(region, animated: true)
        
        // Disable Zoom, scroll and user interaction.
        
        mapView.zoomEnabled = false
        mapView.scrollEnabled = false
        mapView.userInteractionEnabled = false
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Item")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "request == %@", self.requestInfo);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: self.sharedContext,
                                                                  sectionNameKeyPath: nil,
                                                                  cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
    // MARK: - Fetched Results Controller Delegate
    
    // Step 4: This would be a great place to add the delegate methods
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.tableView.beginUpdates()
    }
    
    func controller(controller: NSFetchedResultsController,
                    didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
                                     atIndex sectionIndex: Int,
                                             forChangeType type: NSFetchedResultsChangeType) {
        
        switch type {
        case .Insert:
            self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            
        case .Delete:
            self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
            
        default:
            return
        }
    }
    
    //
    // This is the most interesting method. Take particular note of way the that newIndexPath
    // parameter gets unwrapped and put into an array literal: [newIndexPath!]
    //
    func controller(controller: NSFetchedResultsController,
                    didChangeObject anObject: AnyObject,
                                    atIndexPath indexPath: NSIndexPath?,
                                                forChangeType type: NSFetchedResultsChangeType,
                                                              newIndexPath: NSIndexPath?) {
        
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
            
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            
        case .Update:
            let cell = tableView.cellForRowAtIndexPath(indexPath!) as! ItemsTableViewCell
            let item = controller.objectAtIndexPath(indexPath!) as! Item
            self.configureCell(cell, item: item)
            
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    
    // Configure Cell
    
    func configureCell(cell: ItemsTableViewCell, item: Item) {
        
        cell.itemNameLabel.text = item.itemname
        cell.itemDescriptionLabel.text = item.itemdescription
        
        //        cell.textLabel!.text = request.placename
        //        cell.detailTextLabel!.text = request.delivery_at!.offsetFrom(NSDate())
        
        
    }
    
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        
        return sectionInfo.numberOfObjects
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "ItemCell"
        
        // Here is how to replace the actors array using objectAtIndexPath
        let item = fetchedResultsController.objectAtIndexPath(indexPath) as! Item
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! ItemsTableViewCell
        
        // This is the new configureCell method
        configureCell(cell, item: item)
        
        return cell
        
        
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch (editingStyle) {
        case .Delete:
            
            // Here we get the actor, then delete it from core data
            let item = fetchedResultsController.objectAtIndexPath(indexPath) as! Item
            sharedContext.deleteObject(item)
            CoreDataStackManager.sharedInstance().saveContext()
            
        default:
            break
        }
    }

}


