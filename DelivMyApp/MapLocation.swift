//
//  MapLocation.swift
//  DelivMyApp
//
//  Created by Moh abu on 4/13/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import MapKit

class MapLocation: NSObject {
    
    var region: MKCoordinateRegion
    var centerCoor: CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D!
   
    init(mapView: MKMapView, location: CLLocationCoordinate2D! = nil){
        
        region = mapView.region
        centerCoor = mapView.centerCoordinate
        coordinate = location
        
    }
    
    var locationCoor: [String : AnyObject]  {
        get {
            
            let neLatitude  = centerCoor.latitude  + (region.span.latitudeDelta  / 2.0)
            let neLongitude = centerCoor.longitude + (region.span.longitudeDelta / 2.0)
            let swLatitude = centerCoor.latitude  - (region.span.latitudeDelta  / 2.0)
            let swLongitude = centerCoor.longitude - (region.span.longitudeDelta / 2.0)
            
        let val = ["sw" : "\(swLatitude), \(swLongitude)",
        "ne" : "\(neLatitude), \(neLongitude)",
        "center" : ["\(centerCoor.latitude)", "\(centerCoor.longitude)"] ]
        
        return val as! [String : AnyObject]
            
            }
    }
    
    var checkLocation: Bool {
        get {
            let neLatitude  = centerCoor.latitude  + (region.span.latitudeDelta  / 2.0)
            let neLongitude = centerCoor.longitude + (region.span.longitudeDelta / 2.0)
            let swLatitude = centerCoor.latitude  - (region.span.latitudeDelta  / 2.0)
            let swLongitude = centerCoor.longitude - (region.span.longitudeDelta / 2.0)
            
            if coordinate.latitude > swLatitude && coordinate.latitude < neLatitude  && coordinate.longitude > swLongitude && coordinate.longitude < neLongitude {
                return true
            } else {
                return false
            }
        }
    }
}
