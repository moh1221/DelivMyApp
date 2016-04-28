 //
//  DelivMyClient.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/19/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation

class DelivMyClient: NSObject {
    // MARK: Properties
    
    /* Shared session */
    var session: NSURLSession
    
    
    /* Authentication state */
    var sessionID : String? = nil
    var userID : String? = nil
    
    // MARK: Initializers
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    // Get Method
    func taskForGETMethod(method: String, parameters: [String : AnyObject], completionHandler: (result: AnyObject!, error: NSError?) -> Void) -> NSURLSessionDataTask {
        
        var mutableParameters = parameters
        var mutableResource = method
        // Substitute the id parameter into the resource
        if method.rangeOfString(":id") != nil {
            
            mutableResource = mutableResource.stringByReplacingOccurrencesOfString(":id", withString: "\(parameters[ParameterKeys.ID]!)")
            
            mutableParameters.removeValueForKey(ParameterKeys.ID)
        }
        
        /* Build the URL and configure the request */
        let urlString = DelivMyClient.Constants.DelivMyBaseURL + mutableResource + DelivMyClient.escapedParameters(mutableParameters)
        
        let url = NSURL(string: urlString)!
        let request = NSMutableURLRequest(URL: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        /* Make the request */
        let task = session.dataTaskWithRequest(request) {data, response, error in
            
            /* Parse the data and use the data (happens in completion handler) */
            if let error = error {
                completionHandler(result: nil, error: error)
            } else {
                let newData = data!
                
                DelivMyClient.parseJSONWithCompletionHandler(newData, completionHandler: completionHandler)
            }
        }
        
        /* Start the request */
        task.resume()
        
        return task
    }
    
    
    // POST
    
    func taskForPOSTMethod(method: String, jsonBody: [String:AnyObject], completionHandler: (result: AnyObject!, error: NSError?) -> Void) -> NSURLSessionDataTask {
        
        /* Build the URL and configure the request */
        let urlString = Constants.DelivMyBaseURL + method

        
        let url = NSURL(string: urlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.HTTPBody = try! NSJSONSerialization.dataWithJSONObject(jsonBody, options: .PrettyPrinted)
        }
        
        /* Make the request */
        let task = session.dataTaskWithRequest(request) {data, response, error in
            
            /* Parse the data and use the data (happens in completion handler) */
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                var message: String
                if let response = response as? NSHTTPURLResponse {
                    message = "Invalid Email or Password! Status code: \(response.statusCode)!"
                    
                } else if let response = response {
                    message = "Your request returned an invalid response! Response: \(response)!"
                    
                } else {
                    message = "Your request returned an invalid response!"
                }
                
                let userInfo = [NSLocalizedDescriptionKey : NSLocalizedString(message, comment: "")]
                completionHandler(result: nil, error: NSError(domain: "taskForPOSTMethod", code: 1, userInfo: userInfo))
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                let userInfo = [NSLocalizedDescriptionKey : "No data was returned by the request!"]
                completionHandler(result: nil, error: NSError(domain: "taskForPOSTMethod", code: 1, userInfo: userInfo))
                return
            }
            
            let newData = data
            DelivMyClient.parseJSONWithCompletionHandler(newData, completionHandler: completionHandler)
        }
        
        /* Start the request */
        task.resume()
        
        return task
    }
    
    // Delete
    func taskForDELETEMethod(method: String, completionHandler: (result: AnyObject!, error: NSError?) -> Void) -> NSURLSessionDataTask {
        
        /* Build the URL and configure the request */
        let urlString = DelivMyClient.Constants.DelivMyBaseURL + method
        
        let url = NSURL(string: urlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "DELETE"
        var xsrfCookie: NSHTTPCookie? = nil
        let sharedCookieStorage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        for cookie in sharedCookieStorage.cookies! as [NSHTTPCookie] {
            if cookie.name == "auth_token" { xsrfCookie = cookie }
            sharedCookieStorage.deleteCookie(cookie)
        }
        if let xsrfCookie = xsrfCookie {
            request.setValue(xsrfCookie.value, forHTTPHeaderField: "X-auth_token")
        }
        /* Make the request */
        let task = session.dataTaskWithRequest(request) {data, response, error in
            if error != nil {
                completionHandler(result: false, error: error)
            }
            completionHandler(result: true, error: error)
        }
        
        /* Start the request */
        task.resume()
        
        return task
    }
    
    // MARK: - All purpose task method for images
    
    func taskForImageWithSize(filePath: String, completionHandler: (imageData: NSData?, error: NSError?) ->  Void) -> NSURLSessionTask {
        
        let baseURL = NSURL(string: filePath)!
        
        print(baseURL)
        
        let request = NSURLRequest(URL: baseURL)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                let newError = DelivMyClient.errorForData(data, response: response, error: error)
                completionHandler(imageData: nil, error: newError)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        
        task.resume()
        
        return task
    }

    
    // MARK: Helpers
    // Try to make a better error, based on the status_message from TheMovieDB. If we cant then return the previous error
    
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        if data == nil {
            return error
        }
        
        do {
            let parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments)
            
            if let parsedResult = parsedResult as? [String : AnyObject], errorMessage = parsedResult[DelivMyClient.JSONResponseKeys.ErrorStatusMessage] as? String {
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                return NSError(domain: "TMDB Error", code: 1, userInfo: userInfo)
            }
            
        } catch _ {}
        
        return error
    }
    /* Helper: Given raw JSON, return a usable Foundation object */
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        
        var parsedResult: AnyObject!
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
        } catch {
            let userInfo = [NSLocalizedDescriptionKey : "Could not parse the data as JSON: '\(data)'"]
            completionHandler(result: nil, error: NSError(domain: "parseJSONWithCompletionHandler", code: 1, userInfo: userInfo))
        }
        
        completionHandler(result: parsedResult, error: nil)
    }
    
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    //Singleton
    
    class func sharedInstance() -> DelivMyClient{
        
        struct Singleton {
            static var sharedInstance = DelivMyClient()
        }
        
        return Singleton.sharedInstance
    }
    
    // MARK: - Shared Date Formatter
    
    class var sharedDateFormatter: NSDateFormatter  {
        
        struct Singleton {
            static let dateFormatter = Singleton.generateDateFormatter()
            
            static func generateDateFormatter() -> NSDateFormatter {
                let formatter = NSDateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                
                return formatter
            }
        }
        
        return Singleton.dateFormatter
    }
    
    struct Caches {
        static let imageCache = ImageCache()
    }
}