//
//  UpdateLocationDB.swift
//  pLive
//
//  Created by Duy Truong on 9/20/16.
//  Copyright © 2016 Self. All rights reserved.
//



import Foundation
import CoreLocation
import UIKit
import Firebase


class UpdateLocationDB: NSObject, CLLocationManagerDelegate {
    
    var locationManager = CLLocationManager()
    var userLocation = CLLocation()
    
    /* maybe locationManager is not enough time to update 
     --> don't know how to fix yet. but 5s is some time return 0 and <5 always return 0. look like location frequency update and this # need to be align
     if desiredAccuracy set high (based on relative of distance contanst (eg: kCLLocationAccuracyHundredMeters) --> frequency update in iOS high --> potential of location is 0 is high
     if desiredAccuracy set low  --> frequency update in iOS is low --> potential of location is not 0 is low
    
    --> we need to know exactly how long iOS take update location procedure and store it in coordinate --> so need call update function to DB by multiply this number
    */
    var interval = TimeInterval()
    
    var frequencyUpdate = Timer()
    var ref: FIRDatabaseReference!
    var user = FIRAuth.auth()?.currentUser
    let rangeMonitor = Double(range) //coordinate value return accuray --> to show on map --> this is how accruray in map
    var deviceLatLast = Double()
    var deviceLongLast = Double()
    var deviceLatCurrent: Double = 0
    var deviceLongCurrent: Double = 0
    let delayExecute: Int64 = 5
    
    func checkSignedIn() -> Bool {
        var didSigned: Bool = false
        FIRAuth.auth()?.addStateDidChangeListener { auth, user in
            if let user = user  {
                self.signedIn(user)
                self.user = user
                self.ref = FIRDatabase.database().reference()
                 //try! FIRAuth.auth()!.signOut()
                didSigned = true
            } else { didSigned = false
             // not signed in yet
             //TODO: user FireBase is not sign in  --> go to ViewControler  --> missed something to monitor location after signUp
             // status now: user need to go to app again (after sign up) to record location

            }
        }
        return didSigned
    }
    
  
    
    func inTerminate() {
        frequencyUpdate.invalidate() // stop timer to update to DB
        self.locationManager.stopUpdatingLocation() //stop update location to save enerygy
    }

    func checkLocationStatus() -> Bool {
        var okStartMonitor: Bool = false
        let locationStatus = CLLocationManager.authorizationStatus()
        locationManager.requestAlwaysAuthorization()
        if ((locationStatus == CLAuthorizationStatus.authorizedWhenInUse) || (locationStatus == CLAuthorizationStatus.authorizedAlways)) {
            locationManager.delegate = self
            okStartMonitor = true
        } else {
            switch (locationStatus) {
            case (CLAuthorizationStatus.notDetermined):  print("location status NotDetermined")
            case (CLAuthorizationStatus.restricted):  print("location status Restricted")
            case (CLAuthorizationStatus.denied): print("location Denied")
            default: print("location NOT authorized to use")
                //- TODO something: Unauthorized, requests permissions (intruct user to go to Setting --> Privacy --> Location Service to enable
                // to record location again and makes recursive call

            }
            okStartMonitor = false
        }
        return okStartMonitor
    }
    
    
    
    func execute() {
        let when = DispatchTime.now() + Double(self.delayExecute) // change 2 to desired number of seconds
        DispatchQueue.main.asyncAfter(deadline: when) {
            self.inActive()
        
        }
        
      
    }
    
    func inActive() { // HighFrquency Update and High Accuracy
        if self.checkLocationStatus() {
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters //accuracy in 100m, it mean how accuracy iOS return coordinate. this is good enough to work with pLive
            locationManager.distanceFilter = kCLDistanceFilterNone
            self.interval = Double(tenSecond)
            frequencyUpdate.invalidate() // stop current state of update
            locationManager.startUpdatingLocation()
            frequencyUpdate = Timer.scheduledTimer(timeInterval: self.interval, target: self, selector: #selector(self.updateLocation), userInfo: nil, repeats: true)
        }
    }
    
    func inBackground() { //Low Frequency Update and Low Accuracy
        if self.checkLocationStatus() {
            locationManager.desiredAccuracy = kCLLocationAccuracyKilometer //accuracy in 1km, it mean how accuracy iOS return coordinate. this is good enough to monitor when they are in backGround
            locationManager.distanceFilter = kCLDistanceFilterNone
            //locationManager.allowsBackgroundLocationUpdates = true //apply to get location monitor in background
            locationManager.pausesLocationUpdatesAutomatically = true //apply to energy saving effeciency.
            self.interval = Double(oneMinute)
            frequencyUpdate.invalidate()
            locationManager.startUpdatingLocation()
            frequencyUpdate = Timer.scheduledTimer(timeInterval: self.interval, target: self, selector: #selector(self.updateLocation), userInfo: nil, repeats: true)
        }
    }
    
    func updateLocation() {
        let compareLatCurrent = Double(round(self.deviceLatCurrent * self.rangeMonitor)/self.rangeMonitor)
        let compareLongCurrent = Double(round(self.deviceLongCurrent * self.rangeMonitor)/self.rangeMonitor)
        let compareLatLast = Double(round(self.deviceLatLast * self.rangeMonitor)/self.rangeMonitor)
        let compareLongLast = Double(round(self.deviceLongLast * self.rangeMonitor)/self.rangeMonitor)
        let userLatString = String(format: "%g", compareLatCurrent*self.rangeMonitor)
        let userLongString = String(format: "%g", compareLongCurrent*self.rangeMonitor)
        let placeLocationRef = self.ref!.child("placeLocation")
        //print("before update")
        placeLocationRef.child(userLatString).child(userLongString).child(self.user!.uid).observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.value is NSNull {
                // user never has location data at this location before. --> just update DB
                self.updateDB(self.user!.uid, userLat: compareLatCurrent, userLong: compareLongCurrent, userTime: Date.timeIntervalSinceReferenceDate)
                print("update to DB first time")
            } else { //not null (mean has some lat and long --> remove Current out DB, and update Last to DB)
                
                
                let isLocationChange = ((compareLatCurrent != compareLatLast) || (compareLongCurrent != compareLongLast))
                if (isLocationChange) && (Int(compareLatLast) != 0) && (Int(compareLongLast) != 0) { // location change and ignore 0,0
                   
                    
                    self.removeLocation(compareLatCurrent, userLong: compareLongCurrent, userTime: Date.timeIntervalSinceReferenceDate)
                    self.deviceLatCurrent = self.deviceLatLast
                    self.deviceLongCurrent = self.deviceLongLast
                    //self.updateDB(self.deviceLatCurrent, userLong: self.deviceLongCurrent, userTime: NSDate.timeIntervalSinceReferenceDate())
                    self.updateDB(self.user!.uid ,userLat: compareLatCurrent, userLong: compareLongCurrent, userTime: Date.timeIntervalSinceReferenceDate)
                    print("new location --> update DB")
                    
                } else {
                
                    
                    //print("location not change. no need update to DB")
                    
                }
            }
            })
    }
    func stopUpdate() { self.locationManager.stopUpdatingLocation() }
    
    
    func updateDB(_ id: String, userLat: Double, userLong: Double, userTime: TimeInterval) {
        let placeLocationRef = self.ref!.child("placeLocation")
        let userLatString = String(format: "%g", userLat*self.rangeMonitor) // use this way will switch to scientific notation (e+..) if number becomes too large
        let userLongString = String(format: "%g", userLong*self.rangeMonitor) // use this way will switch to scientific notation (e+..) if number becomes too large
        let placeLocationData: NSDictionary = ["uid": id, "lat":self.deviceLatCurrent,"long":self.deviceLongCurrent,"time":userTime]
      
 
        placeLocationRef.child(userLatString).child(userLongString).child(self.user!.uid).setValue(placeLocationData)
            
    }
    
    func removeLocation(_ userLat: Double, userLong: Double, userTime: TimeInterval) { //apply when app resign and user not allow to monitor location in background
        let placeLocationRef = self.ref!.child("placeLocation")
        let userLatString = String(format: "%g", userLat*self.rangeMonitor) // use this way will switch to scientific notation (e+..) if number becomes too large
        let userLongString = String(format: "%g", userLong*self.rangeMonitor) // use this way will switch to scientific notation (e+..) if number becomes too large
        
        placeLocationRef.child(userLatString).child(userLongString).child(self.user!.uid).observe(.value, with: { snapshot in
            if snapshot.value is NSNull {
                // no userLocation data in PlaceDB --> Do nothing
                //print("no node to remove")
            } else {
                
                //print("remove node")
                placeLocationRef.child(userLatString).child(userLongString).child(self.user!.uid).removeValue()
            }
        })

    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = manager.location
        self.userLocation = location!
        self.deviceLatLast = self.userLocation.coordinate.latitude
        self.deviceLongLast = self.userLocation.coordinate.longitude
        //self.deviceLongLast = Double(round(self.userLocation.coordinate.longitude * self.rangeMonitor)/self.rangeMonitor)
    }
    
    func locationManager(_ _manager: CLLocationManager, didFailWithError error: Error){
    }
    
    func signedIn(_ user: FIRUser?) {
        MeasurementHelper.sendLoginEvent()
        AppState.sharedInstance.displayName = user?.displayName ?? user?.email
        AppState.sharedInstance.photoUrl = user?.photoURL
        AppState.sharedInstance.signedIn = true
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.NotificationKeys.SignedIn), object: nil, userInfo: nil)
      
    }
}



