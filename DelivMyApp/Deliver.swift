//
//  Deliver.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/22/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import UIKit
import CoreData


class Deliver: NSManagedObject {
    struct Keys {
        
        static let ID = "id"
        static let UserId = "user_id"
        static let StatusId = "status_id"
        static let ReceiptImg = "receipt_img"
        static let CompletedAt = "completed_at"
        static let DeliverAt = "delivery_at"
        static let CreatedAt = "created_at"
        
    }
    
    @NSManaged var id: NSNumber
    @NSManaged var user_id: String
    @NSManaged var status_id: NSNumber
    @NSManaged var receipt_img: String?
    @NSManaged var completed_at: NSDate?
    @NSManaged var delivery_at: NSDate?
    @NSManaged var created_at: NSDate?
    @NSManaged var request: Request?
    @NSManaged var profile: Profile?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        //Core Data
        let entity = NSEntityDescription.entityForName("Deliver", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = dictionary[Keys.ID] as! Int
        user_id = dictionary[Keys.UserId] as! String
        status_id = dictionary[Keys.StatusId] as! Int
        receipt_img = dictionary[Keys.ReceiptImg] as? String
        
        if let dateString = dictionary[Keys.CompletedAt] as? String {
            if let date = DelivMyClient.sharedDateFormatter.dateFromString(dateString) {
                completed_at = date
            }
        }
        
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
    
    var receiptImage: UIImage? {
        
        get {
            return DelivMyClient.Caches.imageCache.imageWithIdentifier(receipt_img)
        }
        
        set {
            DelivMyClient.Caches.imageCache.storeImage(newValue, withIdentifier: receipt_img!)
        }
    }
}
