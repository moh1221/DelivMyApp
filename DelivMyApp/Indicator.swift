//
//  Indicator.swift
//  DelivMyApp
//
//  Created by Moh abu on 4/27/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit

extension UIActivityIndicatorView {
    func showIndicator(show: Bool){
        if show {
            self.alpha = 1
            self.startAnimating()
        } else {
            self.alpha = 0
            self.stopAnimating()
        }
    }
}

