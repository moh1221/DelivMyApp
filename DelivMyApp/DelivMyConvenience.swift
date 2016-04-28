//
//  DelivMyConvenience.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/19/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation


extension DelivMyClient{
    
    //Authentication
    func authenticateWithViewController(userAccess: [String: AnyObject], paramKey: String!, completionHandler: (success: Bool, errorString: NSError?) -> Void) {
        
        self.getSession(userAccess, paramKey: paramKey) { (success, result, error) in
            if success {
                completionHandler(success: true, errorString: error)
            } else {
                completionHandler(success: false, errorString: error)
            }
        }
    }
    
    // get session Info
    func getSession(userAccess: [String: AnyObject], paramKey: String!, completionHandler: (success: Bool, result: AnyObject!, errorString: NSError?) -> Void) {
        
        let jsonBody = [ paramKey: userAccess ]
        let mutableMethod : String = Methods.LogIn
        
        /* Make the request */
        taskForPOSTMethod(mutableMethod, jsonBody: jsonBody) { JSONResult, error in
            
            /* Send the desired value(s) to completion handler */
            if let error = error {
                completionHandler(success: false, result: nil, errorString: error)
            } else {
                if let results = JSONResult.valueForKey(DelivMyClient.JSONResponseKeys.Session)?.valueForKey(DelivMyClient.JSONResponseKeys.ID) as? String {
                    self.sessionID = results
                    if let userid = JSONResult.valueForKey(DelivMyClient.JSONResponseKeys.Session)?.valueForKey(DelivMyClient.JSONResponseKeys.UserId) as? String{
                        self.userID = userid
                    }
                    completionHandler(success: true, result: results, errorString: nil)
                } else {
                    completionHandler(success: false, result: nil, errorString: error)
                }
            }
        }
        
    }
    
    
    // Post request
    
    func postRequest(RequestId: [String: AnyObject], paramKey: String!, completionHandler: (success: Bool, result: AnyObject!, errorString: NSError?) -> Void) {
        
        let jsonBody = RequestId
        let mutableMethod : String = paramKey
        
        /* Make the request */
        taskForPOSTMethod(mutableMethod, jsonBody: jsonBody) { JSONResult, error in
            
            /* Send the desired value(s) to completion handler */
            if let error = error {
                completionHandler(success: false, result: nil, errorString: error)
            } else {
                if let results = JSONResult.valueForKey(DelivMyClient.JSONResponseKeys.Message) as? String {
                    completionHandler(success: true, result: results, errorString: nil)
                } else {
                    completionHandler(success: false, result: nil, errorString: error)
                }
            }
        }
        
    }
    
    func deleteSession() -> Void {
        let sharedCookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        for cookie in sharedCookieStorage.cookies! as [NSHTTPCookie] {
            sharedCookieStorage.deleteCookie(cookie)
        }
    }
    
    
    func logoutDelivMy(completionHandler: (success: Bool, errorString: NSError?) -> Void) {
        
        taskForDELETEMethod(Methods.LogOut){ JSONResult, error in
            if let error = error {
                completionHandler(success: false, errorString: error)
                
            } else {
                DelivMyClient.sharedInstance().sessionID = nil
                DelivMyClient.sharedInstance().userID = nil
                completionHandler(success: true, errorString: nil)
                
            }
            
        }
        
    }
}
