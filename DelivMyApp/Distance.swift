//
//  Distance.swift
//  DelivMyApp
//
//  Created by Moh abu on 4/27/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import MapKit

class Distance: NSObject {
    
    var userLocation: CLLocation!
    var requestLocation: CLLocation!
    
    init(userLoc: CLLocation, requestInfo: CLLocation){
        
        self.userLocation = userLoc
        self.requestLocation = requestInfo
        
    }
    
    var disValue: Double {
        get {
            if self.userLocation != nil {
                return self.userLocation.distanceFromLocation(self.requestLocation)
            }
            return 0
        }
    }
}
