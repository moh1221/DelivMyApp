//
//  LoginViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/19/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class LoginViewController: UIViewController, UITextFieldDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginBtn: UIButton!
    @IBOutlet weak var actIndicator: UIActivityIndicatorView!
    
    var shared = SharedView.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Perform the fetch
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("error")
        }
        
        emailTextField.delegate = self
        passwordTextField.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
        
        self.actIndicator.alpha = 0
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Request")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        let predicate = NSPredicate(value: true)
        
        fetchRequest.predicate  = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate] )
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: self.sharedContext,
                                                                  sectionNameKeyPath: nil,
                                                                  cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
  
    @IBAction func signUpBtn(sender: AnyObject) {
        let url = NSURL(string : DelivMyClient.Constants.signupURL)
        UIApplication.sharedApplication().openURL(url!)
    }
    
    
    @IBAction func loginToDelivMy(sender: UIButton) {
        
        if emailTextField.text!.isEmpty {
            
            shared.AlertMessage("Email Empty.", viewControl: self)
            
        } else if passwordTextField.text!.isEmpty {
            
            shared.AlertMessage("Password Empty.", viewControl: self)
            
        } else {
            
            self.actIndicator.showIndicator(true)
            
            let userAccess = [
                DelivMyClient.ParameterKeys.Email : emailTextField.text!,
                DelivMyClient.ParameterKeys.Password : passwordTextField.text!
            ]
            
            DelivMyClient.sharedInstance().authenticateWithViewController(userAccess, paramKey: DelivMyClient.Methods.Session) { (success, errorString) in
                if success {
                    
                    // Remove all existing Requests
                    
                    self.removeRequests()
                    
                    // Compete the login
                    
                    self.completeLogin()
                    
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        if let error: String = errorString!.localizedDescription {
                            self.shared.AlertMessage(error, viewControl: self)
                            self.actIndicator.showIndicator(false)
                        }
                    })
                }
                
            }
        }

    }
    
    // Remove existing Requests
    
    func removeRequests() -> Void {
        for request in self.fetchedResultsController.fetchedObjects as! [Request] {
            dispatch_async(dispatch_get_main_queue()) {
                self.sharedContext.deleteObject(request)
            }
        }
    }
    
    // LoginViewController
    func completeLogin() {
        dispatch_async(dispatch_get_main_queue(), {
            let controller = self.storyboard!.instantiateViewControllerWithIdentifier("ManagerNavigationController") as! UINavigationController
            self.presentViewController(controller, animated: true, completion: nil)
            
            self.actIndicator.showIndicator(false)
        })
    }
}