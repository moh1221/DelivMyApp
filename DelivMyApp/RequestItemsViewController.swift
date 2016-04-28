//
//  RequestItemsViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/29/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class RequestItemsViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    
    var requestInfoItems: Request!
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
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        requestItems()

    }
    @IBAction func cancelItemList(sender: AnyObject) {
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    // load request items
    
    func requestItems(){
        
        if requestInfoItems.items.isEmpty {
            
            let parameters = [ "id": requestInfoItems.id]
            let method = DelivMyClient.Methods.RequestsItems
            
            DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
                if let error = error {
                    
                    self.shared.AlertMessage(error.localizedDescription, viewControl: self)
                    
                } else {
                    
                    if let itemsDictionaries = JSONResult as? [[String : AnyObject]] {
                        // Update the table on the main thread
                        dispatch_async(dispatch_get_main_queue()) {
                            // Parse the array of movies dictionaries
                            let _ = itemsDictionaries.map() { (dictionary: [String : AnyObject]) -> Item in
                                
                                let item = Item(dictionary: dictionary, context: self.sharedContext)
                                item.request = self.requestInfoItems
                                
                                return item
                                
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
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Item")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.predicate = NSPredicate(format: "request == %@", self.requestInfoItems);
        
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
            let cell = tableView.cellForRowAtIndexPath(indexPath!) as! RequestItemCellView
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
    
    func configureCell(cell: RequestItemCellView, item: Item) {
        
        cell.itemNameLabel.text = item.itemname
        cell.descriptionLabel.text = item.itemdescription
        
        //        cell.textLabel!.text = request.placename
        //        cell.detailTextLabel!.text = request.delivery_at!.offsetFrom(NSDate())
        
        
    }
    
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        
        return sectionInfo.numberOfObjects
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "ItemsCell"
        
        // Here is how to replace the actors array using objectAtIndexPath
        let item = fetchedResultsController.objectAtIndexPath(indexPath) as! Item
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier) as! RequestItemCellView
        
        // This is the new configureCell method
        configureCell(cell, item: item)
        
        return cell
    }
}
