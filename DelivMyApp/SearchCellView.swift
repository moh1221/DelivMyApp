//
//  SearchCellView.swift
//  DelivMyApp
//
//  Created by Moh abu on 4/3/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit

class SearchCellView: UICollectionViewCell {
    @IBOutlet weak var ItemsCountLabel: UILabel!
    @IBOutlet weak var deliverAtLabel: UILabel!
    @IBOutlet weak var fessLabel: UILabel!
    @IBOutlet weak var placeNameLabel: UILabel!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var userImage: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var distance: UILabel!
    @IBOutlet weak var searchIndicator: UIActivityIndicatorView!
    
    var taskToCancelifCellIsReused: NSURLSessionTask? {
        
        didSet {
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }
    
}
