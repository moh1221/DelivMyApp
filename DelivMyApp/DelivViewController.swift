//
//  DelivViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/20/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class DelivViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    var shared = SharedView()
    
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
        
        self.refreshControl?.addTarget(self, action: #selector(DelivViewController.refreshDeliver(_:)), forControlEvents: UIControlEvents.ValueChanged)
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        // Load Deliver data
        
        let deliverList = fetchedResultsController.fetchedObjects!
        
        if deliverList.isEmpty {
            loadDeliverList()
        }
    }
    
    func refreshDeliver(sender:AnyObject)
    {
        // Updating your data here...
        let requests = fetchedResultsController.fetchedObjects!
        
        for r in requests {
            let rerquest = r as! Deliver
            sharedContext.deleteObject(rerquest)
        }
        
        CoreDataStackManager.sharedInstance().saveContext()
        loadDeliverList()
        self.tableView.reloadData()
        self.refreshControl?.endRefreshing()
    }
    
    
    func loadDeliverList(){
        
        // Enable newtwork indicator
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        let parameters:[String:AnyObject] = [String:AnyObject]()
        let method = DelivMyClient.Methods.Delivers
        DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
            if let error = error {
                
                self.shared.AlertMessage(error.localizedDescription, viewControl: self)
            
            } else {
                
                if let deliverDictionaries = JSONResult as? [[String : AnyObject]] {
                    
                    dispatch_async(dispatch_get_main_queue()) {
                    // Parse the array of movies dictionaries
                    let _ = deliverDictionaries.map() { (dictionary: [String : AnyObject]) -> Deliver in
                        
                        let request = Request(dictionary: dictionary, context: self.sharedContext)
                        let deliver = Deliver(dictionary: dictionary[DelivMyClient.JSONResponseKeys.Deliver] as! [String : AnyObject], context: self.sharedContext)
                        let profile = Profile(dictionary: dictionary[DelivMyClient.JSONResponseKeys.Profile] as! [String : AnyObject], context: self.sharedContext)
                        
                        deliver.request = request
                        deliver.profile = profile
                        
                        return deliver
                        }
                        
                        CoreDataStackManager.sharedInstance().saveContext()
                        self.tableView.reloadData()
                        
                        // disable newtwork indicator
                        
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    }
                    
                } else {
                    
                    self.shared.AlertMessage("Cant find deliver in \(JSONResult)", viewControl: self)
                }
            }
        }
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Deliver")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "user_id == %@", DelivMyClient.sharedInstance().userID!);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: self.sharedContext,
                                                                  sectionNameKeyPath: nil,
                                                                  cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
    // MARK: - Fetched Results Controller Delegate
    
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
    
    
    // parameter gets unwrapped and put into an array literal: [newIndexPath!]
    
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
            let cell = tableView.cellForRowAtIndexPath(indexPath!) as! DelivViewCell
            let deliver = controller.objectAtIndexPath(indexPath!) as! Deliver
            self.configureCell(cell, deliver: deliver)
            
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }
    
    
    // Configure Cell
    
    func configureCell(cell: DelivViewCell, deliver: Deliver) {
        
        cell.placeNameLabel.text = deliver.request?.placename
        cell.deliverAtLabel.text = deliver.request!.delivery_at.offsetFrom(NSDate())
        cell.placedAtLabel.text = "Placed On \(deliver.request!.created_at.formatted)"
        cell.itemsCountLabel.text = "Total Items \(deliver.request!.items_count)"
        cell.useNameLabel.text = "\(deliver.profile!.first_name) \(deliver.profile!.last_name)"
        
        let stateInfo = Status(status: deliver.status_id)
        cell.statusLabel.text = "Status: \(stateInfo.getStatus())"
        
        if let localImage = deliver.profile!.userImage {
            cell.userImage.image = localImage
        } else if deliver.profile?.picture == nil || deliver.profile?.picture == "" {
            cell.userImage.image = UIImage(named: "UserImage")
        }
            
            // If the above cases don't work, then we should download the image
            
        else {
            
            // Set the placeholder
            cell.userImage.image = UIImage(named: "UserImage")
            
            
            let task = DelivMyClient.sharedInstance().taskForImageWithSize(deliver.profile!.picture!) { (imageData, error) -> Void in
                
                if let data = imageData {
                    dispatch_async(dispatch_get_main_queue()) {
                        let image = UIImage(data: data)
                        deliver.profile!.userImage = image
                        cell.userImage.image = image
                    }
                }
            }
            
            cell.taskToCancelifCellIsReused = task
        }
        
        cell.userImage.layer.cornerRadius = cell.userImage.frame.size.width / 2
        cell.userImage.clipsToBounds = true
    }
}


extension DelivViewController {
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "DelivCell"
        
        // Here is how to replace the actors array using objectAtIndexPath
        let deliver = fetchedResultsController.objectAtIndexPath(indexPath) as! Deliver
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! DelivViewCell
        
        // This is the new configureCell method
        configureCell(cell, deliver: deliver)
        
        return cell
        
        
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let controller =
            storyboard!.instantiateViewControllerWithIdentifier("DelivInfoViewController")
                as! DelivInfoViewController
        
        // Similar to the method above
        let deliver = fetchedResultsController.objectAtIndexPath(indexPath) as! Deliver
        
        controller.deliverInfo = deliver
        
        self.navigationController!.pushViewController(controller, animated: true)
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch (editingStyle) {
        case .Delete:
            
            // Here we get the actor, then delete it from core data
            let deliver = fetchedResultsController.objectAtIndexPath(indexPath) as! Deliver
            sharedContext.deleteObject(deliver)
            CoreDataStackManager.sharedInstance().saveContext()
            
        default:
            break
        }
    }

}
