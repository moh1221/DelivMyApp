//
//  TaskCancelingTableViewCell.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/22/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit

class TaskCancelingTableViewCell: UITableViewCell {
    // The property uses a property observer. Any time its
    // value is set it canceles the previous NSURLSessionTask
    
    @IBOutlet weak var deliveryLabel: UILabel!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var itemsLabel: UILabel!
    @IBOutlet weak var placedLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    var taskToCancelifCellIsReused: NSURLSessionTask? {
        
        didSet {
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }
}
