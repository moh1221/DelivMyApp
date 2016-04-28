//
//  SearchViewController.swift
//  DelivMyApp
//
//  Created by Moh abu on 3/20/16.
//  Copyright © 2016 DelivMy. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class SearchViewController: UIViewController, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var FlowView: UICollectionViewFlowLayout!
    @IBOutlet weak var searchCount: UILabel!
    @IBOutlet weak var freshSwitch: UISwitch!
    
    
    var logoutBtn = UIBarButtonItem()
    var delivBtn = UIBarButtonItem()
    var shared = SharedView.sharedInstance()
    
    // Timer
    var timer = NSTimer()
    
    
    var locationManager: CLLocationManager!
    var userLocation: CLLocation!
    private var mapChangedFromUserInteraction = false
    
    // MARK: - Indexes used for the collection view
    var selectedIndexes = [NSIndexPath]()
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Perform the fetch
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("error")
        }
        
        // Set the delegate to this view controller
        fetchedResultsController.delegate = self
        
        mapView.delegate = self
        
        // Load User Location
        
        loadUserLocation()
        
        // switch value
        freshSwitch.setOn(readAValue(), animated: true)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Load Navigation Items
        loadNavigationItems()
        
        // Flow View
        
        setFlowLayout()
        
        mapView.showsUserLocation = true
        
        locationManager.stopUpdatingLocation()
        
        if fetchedResultsController.fetchedObjects?.count > 0 {
            for request in self.fetchedResultsController.fetchedObjects as! [Request] {
                // add pin
                self.addPinToMap(request)
            }
        }
        
        // Auto Refresh is on
        
        if readAValue() {
            startTimer()
        }
        
    }
    
    // Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Request")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        let predicate1:NSPredicate = NSPredicate(format: "user_id != %@", DelivMyClient.sharedInstance().userID!)
        let predicate2:NSPredicate = NSPredicate(format: "status_id == 1")
        
        fetchRequest.predicate  = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate1,predicate2] )
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
                                                                  managedObjectContext: self.sharedContext,
                                                                  sectionNameKeyPath: nil,
                                                                  cacheName: nil)
        
        return fetchedResultsController
        
    }()
    
    // Request exists
    
    func requestExists (requestId:String) -> Bool {
        let request: NSFetchRequest = NSFetchRequest(entityName: "Request")
        
        let predicate = NSPredicate(format: "id == %@", argumentArray: [requestId])
        
        request.predicate = predicate
        
        let error: NSErrorPointer = nil
        
        let count = self.sharedContext.countForFetchRequest(request, error: error)
        
        if count == 0 {
            return false
        }
        return true
    }
    
    
    // logout from Udacity
    
    func logoutBtnTouchUp(){
        
        shared.delivMYLogout(self)
        
    }
    
    func setFlowLayout() {
        let space: CGFloat = 1.0
        let dimi: CGFloat = (view.frame.size.width - ( space * 2 )) / 2.0
        FlowView.itemSize = CGSizeMake(dimi, dimi)
        FlowView.minimumInteritemSpacing = space
        FlowView.minimumLineSpacing = space
    }
    
    // Reload Request based on map Location
    
    func reloadRequests() -> Void {
        
        let mapLoc = MapLocation(mapView: mapView)
        loadDeliverList(mapLoc.locationCoor)
    }
    
    func loadDeliverList(locationCoor: [String : AnyObject]){
        
        // Enable newtwork indicator
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        let parameters: [String : AnyObject] = locationCoor
        let method = DelivMyClient.Methods.Search
        
        DelivMyClient.sharedInstance().taskForGETMethod(method, parameters: parameters){ JSONResult, error  in
            if let error = error {
                
                self.shared.AlertMessage(error.localizedDescription, viewControl: self)
                
            } else {
                
                self.updateSearchCounter(JSONResult.count)
                if let searchDictionaries = JSONResult as? [[String : AnyObject]] {
                    // Update the table on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        // Parse the array of movies dictionaries
                        let _ = searchDictionaries.map() { (dictionary: [String : AnyObject]) in
                        
                        
                            let requestId: String = "\(dictionary["id"]!)"
                        
                            if !self.requestExists(requestId){
                                    let request = Request(dictionary: dictionary, context: self.sharedContext)
                                    let profile = Profile(dictionary: dictionary[DelivMyClient.JSONResponseKeys.Profile] as! [String : AnyObject], context: self.sharedContext)
                                    let location = Location(dictionary: dictionary[DelivMyClient.JSONResponseKeys.Location] as! [String : AnyObject], context: self.sharedContext)
                            
                                    request.profile = profile
                                    request.location = location
                            
                                    self.addPinToMap(request)
                                
                            }
                        }
                        CoreDataStackManager.sharedInstance().saveContext()
                        
                        // disable newtwork indicator
                        
                        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                    }
                } else {
                    
                    self.shared.AlertMessage("Cant find deliver in \(JSONResult)", viewControl: self)
                    
                }
            }
        }
    }
    
    // Search counter update
    
    func updateSearchCounter(count: Int) -> Void{
        
        dispatch_async(dispatch_get_main_queue()) {
            self.searchCount.text = "Total Requests: \(count)"
        }
    }
    
    // Auto Refresh switch action
    
    @IBAction func refreshSwitchChanged(sender: AnyObject) {
        if freshSwitch.on {
            
            saveAValue(true)
            startTimer()
            
        } else {
            
            saveAValue(false)
            timer.invalidate()
        }
    }
    
    func saveAValue(val: Bool) {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        // Save a Bool value into the defaults, using the key "mySwitch"
        defaults.setBool(val, forKey: "mySwitch")
    }
    
    func readAValue() -> Bool {
        // Read the current value for the "mySwitch" key
        let defaults = NSUserDefaults.standardUserDefaults()
        return defaults.boolForKey("mySwitch")
        
    }
    
    func startTimer() -> Void {
        timer = NSTimer.scheduledTimerWithTimeInterval(15.0, target: self, selector: #selector(SearchViewController.reloadRequests), userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer, forMode: NSRunLoopCommonModes)
    }
    
    // Load Items
    func loadNavigationItems(){
        
        logoutBtn = UIBarButtonItem(title: "Logout", style: .Plain, target: self, action: #selector(SearchViewController.logoutBtnTouchUp))
        
        self.parentViewController!.navigationItem.leftBarButtonItems = [logoutBtn]
        
        self.parentViewController!.navigationItem.hidesBackButton = true
    }
    
    func indicatorUpdate(cell: SearchCellView, value: Bool) -> Void{
        if value {
//            let space: CGFloat = 3.0
//            let dimi: CGFloat = (view.frame.size.width - ( space * 2 )) / 3.0
//            cell.searchIndicator.center = CGPointMake(dimi/2, dimi/2)
            cell.searchIndicator.alpha = 1
            cell.searchIndicator.startAnimating()
            
            
        } else {
            cell.searchIndicator.stopAnimating()
            cell.searchIndicator.alpha = 0
        }
    }
    
    // Configure Cell
    
    func configureCell(cell: SearchCellView, request: Request) {
        
        // Start Indicator
        
        indicatorUpdate(cell, value: true)
        
        // Update label text 
        
        cell.placeNameLabel.text = request.placename
        cell.ItemsCountLabel.text = "\(request.items_count) Items"
        cell.categoryLabel.text = request.category_name
        cell.fessLabel.text = "$\(request.fees)"
        cell.deliverAtLabel.text = request.delivery_at.offsetFrom(NSDate())
        
        // Calc Distance from user Location
        if let loc = request.location {
            
            let ff = CLLocation(latitude: loc.lat, longitude: loc.long)
            var dis = 0.0
            if userLocation != nil {
                dis = userLocation.distanceFromLocation(ff)
            }
            
            let disMiles = NSString(format: "%.01f", dis * 0.000621371)
            
            cell.distance.text = "Dist: \(disMiles)mi"
        }
        
        // add Profile info
        if let profile = request.profile {
            cell.userNameLabel.text = "\(profile.first_name) \(profile.last_name)"
            
            if let localImage = request.profile!.userImage {
                cell.userImage.image = localImage
            } else if request.profile?.picture == nil || request.profile?.picture == "" {
                cell.userImage.image = UIImage(named: "UserImage")
            }
            else {
                
                // Set the placeholder
                
                cell.userImage.image = UIImage(named: "UserImage")
                
                let task = DelivMyClient.sharedInstance().taskForImageWithSize(request.profile!.picture!) { (imageData, error) -> Void in
                    
                    if let data = imageData {
                        dispatch_async(dispatch_get_main_queue()) {
                            let image = UIImage(data: data)
                            request.profile!.userImage = image
                            cell.userImage.image = image
                        }
                    }
                }
                
               cell.taskToCancelifCellIsReused = task
            }
            // End Indicator
            
            indicatorUpdate(cell, value: false)
        }
    }
}

extension SearchViewController: MKMapViewDelegate, CLLocationManagerDelegate {
    // User Location
    
    func loadUserLocation() -> Void {
        
        if (CLLocationManager.locationServicesEnabled())
        {
            locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
            
        }
        
        let status = CLLocationManager.authorizationStatus()
        if status == .NotDetermined || status == .Denied || status == .AuthorizedWhenInUse {
            // present an alert indicating location authorization required
            // and offer to take the user to Settings for the app via
            // UIApplication -openUrl: and UIApplicationOpenSettingsURLString
            locationManager.requestAlwaysAuthorization()
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // Map
    
    func addPinToMap(request: Request) {
        
        var annotations = [MKPointAnnotation]()
        
        if let locations = request.location {
            
            // GEO related items
            let lat = CLLocationDegrees(locations.lat)
            let long = CLLocationDegrees(locations.long)
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: long)
            
            //User info
            let first = request.placename
            let last = request.category_name
            
            //Create our annotation with everything
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "\(first) \(last)"
            
            annotations.append(annotation)
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            self.mapView.addAnnotations(annotations)
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        userLocation = locations.last
        
        let location = locations.last
        let center = CLLocationCoordinate2D(latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
        self.mapView.setRegion(region, animated: false)
        
        reloadRequests()
    }
    
    private func mapViewRegionDidChangeFromUserInteraction() -> Bool {
        let view = self.mapView.subviews[0]
        //  Look through gesture recognizers to determine whether this region change is from user interaction
        if let gestureRecognizers = view.gestureRecognizers {
            for recognizer in gestureRecognizers {
                if( recognizer.state == UIGestureRecognizerState.Began || recognizer.state == UIGestureRecognizerState.Ended ) {
                    return true
                }
            }
        }
        return false
    }
    
    func mapView(mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        mapChangedFromUserInteraction = mapViewRegionDidChangeFromUserInteraction()
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if (mapChangedFromUserInteraction) {
            
            // user changed map region
            reloadRequests()
            
            updatePins()
        }
    }
    
    func updatePins() -> Void {
        // Remove existing pins
        let annotationsToRemove = mapView.annotations.filter { $0 !== mapView.userLocation }
        mapView.removeAnnotations( annotationsToRemove )
        
        for request in self.fetchedResultsController.fetchedObjects as! [Request] {
            
            let mapL = MapLocation(mapView: self.mapView, location: request.location!.coordinate)
            
            if mapL.checkLocation {
                
                self.addPinToMap(request)
                
            } else {
                
                self.sharedContext.deleteObject(request)
            }
            
        }
        
        self.updateSearchCounter(self.fetchedResultsController.fetchedObjects!.count)
        
    }

}

extension SearchViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cellIdentifier = "SearchCell"
        
        // Here is how to replace the actors array using objectAtIndexPath
        let request = fetchedResultsController.objectAtIndexPath(indexPath) as! Request
        
        
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(cellIdentifier, forIndexPath: indexPath) as! SearchCellView
        //        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCell
        
        configureCell(cell, request: request)
        
        return cell
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        
        if let objectNumber = self.fetchedResultsController.sections?.count {
            return objectNumber
        }else{
            return 0
        }
        
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let controller =
            storyboard!.instantiateViewControllerWithIdentifier("SearchInfoViewController")
                as! SearchInfoViewController
        
        // Similar to the method above
        let request = fetchedResultsController.objectAtIndexPath(indexPath) as! Request
        
        controller.searchInfo = request
        
        if let loc = request.location {
            
            let ff = CLLocation(latitude: loc.lat, longitude: loc.long)
            var dis = 0.0
            if userLocation != nil {
                dis = userLocation.distanceFromLocation(ff)
            }
            
            let disMiles = NSString(format: "%.01f", dis * 0.000621371)
            
            controller.distanceInfo = "Dist: \(disMiles)mi"
        }
        
        
        self.presentViewController(controller, animated: true, completion: nil)
    }
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    // MARK: - Fetched Results Controller Delegate
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type{
            
        case .Insert:
            self.insertedIndexPaths.append(newIndexPath!)
            break
        case .Delete:
            self.deletedIndexPaths.append(indexPath!)
            updatePins()
            break
        case .Update:
            self.updatedIndexPaths.append(indexPath!)
            break
            
        default:
            break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        
        self.collectionView.performBatchUpdates({() -> Void in
            
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItemsAtIndexPaths([indexPath])
            }
            
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItemsAtIndexPaths([indexPath])
            }
            
            }, completion: nil)
    }

}