//
//  ViewController.swift
//  pLive
//
//  Created by Duy Truong on 8/30/16.
//  Copyright © 2016 Self. All rights reserved.
//

import UIKit
import Firebase
import FBSDKCoreKit
import FBSDKLoginKit


class ViewController: UIViewController, GIDSignInDelegate, GIDSignInUIDelegate {
 
    /*
    public func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
     
    }
     
     
     func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
     withError error: NSError!) {
     

    */
    
    @IBOutlet weak var userPassword: UITextField!
    @IBOutlet weak var userEmail: UITextField!
 
    //-----reset pasword - not test yet -----
    @IBAction func didTapReset(_ sender: AnyObject) {
        let prompt = UIAlertController.init(title: nil, message: "Email:", preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction.init(title: "OK", style: UIAlertActionStyle.default) { (action) in
            let userInput = prompt.textFields![0].text
            if (userInput!.isEmpty) {
                return
            }
            FIRAuth.auth()?.sendPasswordReset(withEmail: userInput!) { (error) in
                if let error = error { self.errorToScreen(error.localizedDescription) }
            }
        }
        prompt.addTextField(configurationHandler: nil)
        prompt.addAction(okAction)
        present(prompt, animated: true, completion: nil)
    }
    //------end reset pasword ----------
    
    func errorToScreen(_ error: String) -> Void
    {
        self.logInStatus.isHidden = false
        self.logInStatus.text = error
        
    }
    
    
     @IBOutlet weak var logInStatus: UILabel!
    
    //------ sign up for new firebase account ---
     @IBAction func didTapSignUp(_ sender: AnyObject) {
        let email = userEmail.text
        let password = userPassword.text
        FIRAuth.auth()?.createUser(withEmail: email!, password: password!) {
            (user, error) in
            if let error = error { self.errorToScreen(error.localizedDescription) }
        }
     }
    //------ end firebase account sign up-------
    
    //------- sig in with fb -------------------
     @IBAction func didTapFacebook(_ sender: AnyObject) {
  
        let fbLogInManager = FBSDKLoginManager()
        //fbLogInManager.logOut()
        if (FBSDKAccessToken.current() == nil) {
            fbLogInManager.logIn(withReadPermissions: ["email"], from: self) { (result, error) in
                if (error == nil) {
                    let fbLogInResult : FBSDKLoginManagerLoginResult = result!
                    if (fbLogInResult.grantedPermissions != nil) && (fbLogInResult.grantedPermissions.contains("email")) {
                        let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
                        FIRAuth.auth()?.signIn(with: credential) { (user, error) in
                            if let error = error {self.errorToScreen(error.localizedDescription)}}
                        }
                }
            }
        } else {
            let credential = FIRFacebookAuthProvider.credential(withAccessToken: FBSDKAccessToken.current().tokenString)
            FIRAuth.auth()?.signIn(with: credential) { (user, error) in
                if let error = error {self.errorToScreen(error.localizedDescription)}}
        }
    }
    // ------- end sign in with fb -------
    
   
    //---------------- Sign In with email/password -------------------
    @IBAction func didTapSignIn(_ sender: AnyObject) {
        
        let email = userEmail.text
        let password = userPassword.text
        let credential = FIREmailPasswordAuthProvider.credential(withEmail: email!, password: password!)
        FIRAuth.auth()?.signIn(with: credential) { (user, error) in
            if let error = error {self.errorToScreen(error.localizedDescription)}}
    }
    //------------- end sign in with email/password --------------
    
    
    // ----- signed in with current firebase user --------------
    func signedIn(_ user: FIRUser?) {
        MeasurementHelper.sendLoginEvent()
        AppState.sharedInstance.displayName = user?.displayName ?? user?.email
        AppState.sharedInstance.photoUrl = user?.photoURL
        AppState.sharedInstance.signedIn = true
        NotificationCenter.default.post(name: Notification.Name(rawValue: Constants.NotificationKeys.SignedIn), object: nil, userInfo: nil)
        
        
        // do something here to check role (or check receive notification) to perform Segue 
        // if viewer --> go to Map View
        // if streamer --> go to NegotiationView
        
        performSegue(withIdentifier: Constants.Segues.SignInToFp, sender: nil) //this perform go to next screen after sign in
    }
    // ------- end sign in current firebase user ------
    
    
    // ----------  Authenticate with Google Account ----------------
    @IBAction func didTapGoogle(_ sender: AnyObject) {
        GIDSignIn.sharedInstance().clientID = FIRApp.defaultApp()?.options.clientID
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        if (GIDSignIn.sharedInstance().currentUser != nil) {
            GIDSignIn.sharedInstance().signInSilently()
        } else {
            GIDSignIn.sharedInstance().signIn()
        }
    }
    
    public func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!,
                withError error: Error!) {

        let authentication = user.authentication
        let credential = FIRGoogleAuthProvider.credential(withIDToken: (authentication?.idToken)!,
                                                                     accessToken: (authentication?.accessToken)!)
        if (FIRAuth.auth()?.currentUser == nil) {
            FIRAuth.auth()?.signIn(with: credential) { (user, error) in
            if let error = error {self.errorToScreen(error.localizedDescription)}}
        }
            
    }
    
    func sign(_ signIn: GIDSignIn!, didDisconnectWith user:GIDGoogleUser!,
                withError error: Error!) {
    }
    // ----- end of authenticate Google Account ---------
    
    
    override var shouldAutorotate : Bool { return false }
    
    override func viewDidAppear(_ animated: Bool) {
        // Do any additional setup after loading the view, typically from a nib
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        view.addGestureRecognizer(tap) // to dismiss keyboard when tap anywhere
        
      
        
        FIRAuth.auth()?.addStateDidChangeListener { auth, user in
            if let user = user  {self.signedIn(user)
           //try! FIRAuth.auth()!.signOut()
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func dismissKeyboard() { view.endEditing(true) }
}

