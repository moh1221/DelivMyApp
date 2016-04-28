//
//  Request.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/24/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import CoreData

class Request: NSManagedObject {
    struct Keys {
        static let ID = "id"
        static let UserId = "user_id"
        static let PlaceName = "PlaceName"
        static let StatusId = "status_id"
        static let CategoryId = "category_id"
        static let category = "category"
        static let catname = "CatName"
        static let Cost = "cost"
        static let Fees = "fees"
        static let DeliverAt = "delivery_at"
        static let CreatedAt = "created_at"
        static let Items = "items"
    }
    
    @NSManaged var id: NSNumber
    @NSManaged var user_id: String
    @NSManaged var placename: String
    @NSManaged var status_id: NSNumber
    @NSManaged var category_id: NSNumber
    @NSManaged var category_name: String
    @NSManaged var cost: NSNumber
    @NSManaged var fees: NSNumber
    @NSManaged var delivery_at: NSDate
    @NSManaged var created_at: NSDate
    @NSManaged var items_count: NSNumber
    @NSManaged var items: [Item]
    @NSManaged var location: Location?
    @NSManaged var deliver: Deliver?
    @NSManaged var profile: Profile?
    
    
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        //Core Data
        let entity = NSEntityDescription.entityForName("Request", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = dictionary[Keys.ID] as! Int
        user_id = dictionary[Keys.UserId] as! String
        placename = dictionary[Keys.PlaceName] as! String
        status_id = dictionary[Keys.StatusId] as! Int
        category_id = dictionary[Keys.CategoryId] as! Int
        category_name = dictionary[Keys.category]![Keys.catname] as! String
        cost = dictionary[Keys.Cost] as! NSNumber
        fees = dictionary[Keys.Fees] as! NSNumber
        items_count = dictionary[Keys.Items]!.count as NSNumber
        
        if let dateString = dictionary[Keys.DeliverAt] as? String {
            if let date = DelivMyClient.sharedDateFormatter.dateFromString(dateString) {
                delivery_at = date
                
            }
        }
        
        if let dateString = dictionary[Keys.CreatedAt] as? String {
            if let date = DelivMyClient.sharedDateFormatter.dateFromString(dateString) {
                created_at = date
            }
        }
    }

}
