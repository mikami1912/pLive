//
//  AppDelegate.swift
//  pLive
//
//  Created by Duy Truong on 8/30/16.
//  Copyright © 2016 Self. All rights reserved.
//

import Firebase
import GoogleMaps
import GooglePlaces


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var update = UpdateLocationDB.init()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FIRApp.configure()
        GMSServices.provideAPIKey(googleMapsAPIKey)
        GMSPlacesClient.provideAPIKey(googlePlaceAPIKey)
        
        if (update.checkSignedIn()) {
            update.execute()
        } else { // user not signed in yet --> go to view controller to signed . but still STUPID flow here --> user need to terminate app and start again to monitor location
        }
        return true
        
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        
        
        let googleDidHandle = GIDSignIn.sharedInstance().handle(url,sourceApplication: sourceApplication, annotation: annotation)
        let facebookDidHandle = FBSDKApplicationDelegate.sharedInstance().application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
        
        return   facebookDidHandle || googleDidHandle
        
    }
    /*
    func application(application: UIApplication, openURL url: NSURL, options: [String: AnyObject]) -> Bool { // for iOS 8.0 or older
  
        let googleDidHandle = GIDSignIn.sharedInstance().handleURL(url, sourceApplication: options[UIApplicationOpenURLOptionsSourceApplicationKey] as? String,
                                                                  annotation: options[UIApplicationOpenURLOptionsAnnotationKey])
        let facebookDidHandle = FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url,
            sourceApplication: options[UIApplicationOpenURLOptionsSourceApplicationKey] as? String,
            annotation: options[UIApplicationOpenURLOptionsAnnotationKey])
        return facebookDidHandle || googleDidHandle
    }
 
    */
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        //--> stop send user Notification to request streaming (entern Negotiation State)
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
   
        
        /*do something to still monitor user location and save data to DB but with:
         -  low frequency : increase interval to 1mins (current value is store in interval variable in class UpdateLocationDB
         -  low accuracy  : descreace accunray to km (current value is kCLLocationAccuracyHundredMeters in class UpdateLocationDB
         */

        update.inBackground()
        
        
        
        
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        FBSDKAppEvents.activateApp()
        
        
        
        /*do something to restore default high frequency & accuray update location and save to DB
         -  high frequency : descrease interval to interval defaul (current value is store in interval variable in class UpdateLocationDB
         -  low accuracy  : increase accunracy to 100m (current value is kCLLocationAccuracyHundredMeters in class UpdateLocationDB
         *  --> DONE  */
        update.inActive()
        
        
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        /*
         As long as the app still running in the background (update user location --> save to DB). User always BE requested to stream data (through Push Notification), coz core value of pLive is stream LIVED video at LOCATION, which mean this location need someone ready to stream. if pLive can't record user location data --> no need to ask user to stream coz we dont' know where they are so they can't ready to stream.
         
         Need to make some BUTTON in UI to do something like TERMINATE absolutely (same function as manually terminate by user action (double click home button and swipe unused app) in device) and stop record userLocation. This button (or manualy remove app by double click Home button and remove) need to implement:
         - stop record userLocation Data
         - remove userLocation Data out of placeLocation DB Node coz we don't know how user move after stop and not gurantee user still there . So if we request user (after terminate app) in placeLocation table, there is high potential we get wrong data.
         */
        
        
        
        
        /*
            - stop monitor userLocation --> DONE
            - remove user out of placeLocation --> Not yet
        */
       
        update.inTerminate() //stop monitor
        // update.removeUserOutPlaceDB() --> remove userLocation out of DB --> HOLD>
        update.stopUpdate()
        
    }


}

