//
//  Profile.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/22/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import UIKit
import CoreData

class Profile: NSManagedObject {
    struct Keys {
        static let FirstName = "first_name"
        static let LastName = "last_name"
        static let Picture = "picture"
        static let Profile = "profile"
    }
    
    @NSManaged var first_name: String
    @NSManaged var last_name: String
    @NSManaged var picture: String?
    @NSManaged var request: Request?
    @NSManaged var deliver: Deliver?
    
    
    
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        //Core Data
        let entity = NSEntityDescription.entityForName("Profile", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        first_name = dictionary[Keys.FirstName] as! String
        last_name = dictionary[Keys.LastName] as! String
        picture = dictionary[Keys.Picture] as? String
    }
    
    var userImage: UIImage? {
        
        get {
            return DelivMyClient.Caches.imageCache.imageWithIdentifier(picture)
        }
        
        set {
            DelivMyClient.Caches.imageCache.storeImage(newValue, withIdentifier: picture!)
        }
    }

}

