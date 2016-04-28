//
//  DelivViewCell.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/30/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import UIKit

class DelivViewCell: UITableViewCell {
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var placeNameLabel: UILabel!
    @IBOutlet weak var placedAtLabel: UILabel!
    @IBOutlet weak var deliverAtLabel: UILabel!
    @IBOutlet weak var itemsCountLabel: UILabel!
    @IBOutlet weak var useNameLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    
    var taskToCancelifCellIsReused: NSURLSessionTask? {
        
        didSet {
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }
}
