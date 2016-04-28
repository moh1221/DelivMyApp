//
//  DelivMyConstants.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/19/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation

extension DelivMyClient{
    // Constants
    struct Constants {
        
        // URLs
        
        static let DelivMyBaseURL = "https://delivmy.com/"
        
    }
    
    // Methods
    struct Methods {
        
        // Account
        static let LogIn = "login"
        static let LogOut = "logout"
        static let SignUp = "signup"
        static let Session = "session"
        
        // Requests
        static let Requests = "requests"
        static let RequestsItems = "requests/:id/items"
        static let RequestsLocations = "requests/:id/locations"
        
        
        // Search
        static let Search = "search"
        
        // Delivers
        static let Delivers = "delivers"
        static let DeliversRequestId = "delivers/:id"
        static let DeliversNew = "delivers/new"
        
        // Users
        static let User = "user"
        static let Profile = "profile"
        
    }
    
    // Parameter Keys
    struct ParameterKeys {
        // General
        static let ID = "id"
        static let RequestID = "request_id"
        static let Email = "email"
        static let Password = "password"
        static let SW = "sw"
        static let NE = "ne"
        static let Center = "center"
        
    }
    
    // JSON Response Keys
    struct JSONResponseKeys {
        
        // General
        static let Session = "session"
        static let Message = "message"
        static let Auth_token = "auth_token"
        static let ID = "id"
        static let UserId = "user_id"
        static let first_name = "first_name"
        static let last_name = "last_name"
        static let ErrorStatusMessage = "status_message"
        static let Profile = "profile"
        static let Location = "location"
        static let Deliver = "deliver"
    }
    
}