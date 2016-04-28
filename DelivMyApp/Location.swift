//
//  Location.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/22/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class Location: NSManagedObject, MKAnnotation {
    struct Keys {
        static let ID = "id"
        static let Address = "address"
        static let Lat = "Lat"
        static let Long = "Long"
    }
    
    @NSManaged var id: NSNumber
    @NSManaged var address: String
    @NSManaged var lat: Double
    @NSManaged var long: Double
    @NSManaged var request: Request?
    
    var calculatedCoordinate : CLLocationCoordinate2D? = nil
    
    // MARK: - Parameter to fulfill mkkannotation class
    var coordinate: CLLocationCoordinate2D {
        return calculatedCoordinate!
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        calculatedCoordinate = CLLocationCoordinate2DMake(lat as Double, long as Double)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        //Core Data
        let entity = NSEntityDescription.entityForName("Location", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = dictionary[Keys.ID] as! Int
        address = dictionary[Keys.Address] as! String
        lat = dictionary[Keys.Lat] as! Double
        long = dictionary[Keys.Long] as! Double
        
        self.calculatedCoordinate = CLLocationCoordinate2DMake(lat as Double, long as Double)
    }
}
