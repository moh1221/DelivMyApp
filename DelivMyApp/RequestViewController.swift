//
//  RequestViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/20/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import CoreData
import UIKit


class RequestViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
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
        
        self.refreshControl?.addTarget(self, action: #selector(RequestViewController.refresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        let requestList = fetchedResultsController.fetchedObjects!
        
        if requestList.isEmpty {
            loadRequestList()
        }
    }
    
    func refresh(sender:AnyObject)
    {
        // Updating your data here...
        let requests = fetchedResultsController.fetchedObjects!
        
        for r in requests {
            let rr = r as! Request
            sharedContext.deleteObject(rr)
        }
        
        CoreDataStackManager.sharedInstance().saveContext()
        
        loadRequestList()
        
        self.tableView.reloadData()
        self.refreshControl?.endRefreshing()
    }
    
    func loadRequestList(){
        
        let parameters:[String:AnyObject] = [String:AnyObject]()
        let method = DelivMyClient.Methods.Requests
        
        DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
            if let error = error {
                
                self.shared.AlertMessage(error.localizedDescription, viewControl: self)
                
            } else {
                
                if let requestDictionaries = JSONResult as? [[String : AnyObject]] {
                    dispatch_async(dispatch_get_main_queue()) {
                        // Parse the array of movies dictionaries
                        let _ = requestDictionaries.map() { (dictionary: [String : AnyObject]) -> Request in
                        
                            let request = Request(dictionary: dictionary, context: self.sharedContext)
                        
                            if let deliveryDictionary = dictionary[DelivMyClient.JSONResponseKeys.Deliver] {
                                let deliver = Deliver(dictionary: deliveryDictionary as! [String : AnyObject], context: self.sharedContext)
                                let profile = Profile(dictionary: deliveryDictionary[DelivMyClient.JSONResponseKeys.Profile] as! [ String : AnyObject], context: self.sharedContext)
                                deliver.request = request
                                deliver.profile = profile
                            }
                            return request
                        }
                    
                        CoreDataStackManager.sharedInstance().saveContext()
                        self.tableView.reloadData()
                    }
                } else {
                    
                    self.shared.AlertMessage("Cant find request in \(JSONResult)", viewControl: self)
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
        
        let fetchRequest = NSFetchRequest(entityName: "Request")
        
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
            let cell = tableView.cellForRowAtIndexPath(indexPath!) as! TaskCancelingTableViewCell
            let request = controller.objectAtIndexPath(indexPath!) as! Request
            self.configureCell(cell, request: request)
            
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.tableView.endUpdates()
    }

    
    // Configure Cell
    
    func configureCell(cell: TaskCancelingTableViewCell, request: Request) {
        
        cell.placeLabel.text = request.placename
        cell.deliveryLabel.text = request.delivery_at.offsetFrom(NSDate())
        cell.placedLabel.text = "Placed On \(request.created_at.formatted)"
        cell.itemsLabel.text = "\(request.items_count) Items"
        
        let stateInfo = Status(status: request.status_id)
        
        cell.statusLabel.text = "Status: \(stateInfo.getStatus())"
    }
}

extension RequestViewController {
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "RequestCell"
        
        // Here is how to replace the actors array using objectAtIndexPath
        let request = fetchedResultsController.objectAtIndexPath(indexPath) as! Request
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! TaskCancelingTableViewCell
        
        // This is the new configureCell method
        configureCell(cell, request: request)
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let controller =
            storyboard!.instantiateViewControllerWithIdentifier("RequestInfoViewController")
                as! RequestInfoViewController
        
        // Similar to the method above
        let request = fetchedResultsController.objectAtIndexPath(indexPath) as! Request
        
        controller.requestInfo = request
        
        self.navigationController!.pushViewController(controller, animated: true)
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        switch (editingStyle) {
        case .Delete:
            
            // Here we get the actor, then delete it from core data
            let request = fetchedResultsController.objectAtIndexPath(indexPath) as! Request
            sharedContext.deleteObject(request)
            CoreDataStackManager.sharedInstance().saveContext()
            
        default:
            break
        }
    }
}

