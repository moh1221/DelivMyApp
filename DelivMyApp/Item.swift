//
//  Item.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/22/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import CoreData

class Item: NSManagedObject {
    struct Keys {
        static let ID = "id"
        static let ItemsName = "ItemsName"
        static let ItemDescription = "ItemDescription"
        static let CreatedAt = "created_at"
    }
    
    @NSManaged var id: NSNumber
    @NSManaged var itemname: String
    @NSManaged var itemdescription: String
    @NSManaged var created_at: NSDate
    @NSManaged var request: Request?
    
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        //Core Data
        let entity = NSEntityDescription.entityForName("Item", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = dictionary[Keys.ID] as! Int
        itemname = dictionary[Keys.ItemsName] as! String
        itemdescription = dictionary[Keys.ItemDescription] as! String
        
        if let dateString = dictionary[Keys.CreatedAt] as? String {
            if let date = DelivMyClient.sharedDateFormatter.dateFromString(dateString) {
                created_at = date
            }
        }
    }

    
}
