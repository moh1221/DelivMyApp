//
//  SharedView.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/20/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit

class SharedView: NSObject {
    
    // Alert message
    func AlertMessage(message: String, viewControl: AnyObject){
        
        let alert = UIAlertController(title: "", message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let dismissAction = UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Default, handler: nil)
        
        alert.addAction(dismissAction)
        viewControl.presentViewController(alert, animated: true, completion: nil)
        
    }
    
    func delivMYLogout(viewControl: AnyObject){
        DelivMyClient.sharedInstance().logoutDelivMy() { (success, errorString) in
            if success {
                self.completeLogout(viewControl)
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    if let error: String = errorString!.localizedDescription {
                        self.AlertMessage(error, viewControl: viewControl)
                    }
                })
            }
        }
    }
    
    func completeLogout(viewControl: AnyObject) {
        dispatch_async(dispatch_get_main_queue(), {
            viewControl.navigationController?!.dismissViewControllerAnimated(true, completion: nil)
        })
    }
    
    class func sharedInstance() -> SharedView {
        
        struct Singleton {
            static var sharedInstance = SharedView()
        }
        
        return Singleton.sharedInstance
    }
}
