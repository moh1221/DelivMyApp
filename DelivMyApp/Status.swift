//
//  Status.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/22/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation

class Status {
    let statuses: NSNumber = 0
    let statusVal: String?
    
    init(status: NSNumber){
        
        var Value: String
        
        switch status {
            case 1: Value = "Open"
            case 2: Value = "On Progress"
            case 3: Value = "Completed"
            case 4: Value = "Closed"
            case 5: Value = "Rejected"
            default: Value = "Open"
        }
        
        self.statusVal = Value
    }
    
    func getStatus() -> String {
        return self.statusVal!
    }
}
