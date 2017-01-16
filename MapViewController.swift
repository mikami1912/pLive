//
//  MapViewController.swift
//  pLive
//
//  Created by Duy Truong on 9/27/16.
//  Copyright © 2016 Self. All rights reserved.
//

import Firebase
import GoogleMaps
import GooglePlaces


class MapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {
    @IBOutlet weak var acceptRequest: UIButton!
    @IBOutlet weak var notification: UILabel!
    @IBOutlet weak var rejectRequest: UIButton!

  
    var user = FIRAuth.auth()?.currentUser
    var locationManager = CLLocationManager()
    var userLocation = CLLocation()
    var frequencyUpdate = Timer()
    var ref = FIRDatabase.database().reference()
    let requestButHeight: Double = 37.0 // don't know how to get height of button yet.
    var mapView =  GMSMapView()
    let oneKmZoom: Float = 16.0
    let delayExecute: Int64 = 5
    let runtime: Int64 = 5
    var requestServiceMarker = GMSMarker()
    var cameraPosition = GMSCameraPosition()
    var loadMapPercentage: Int = 0
    let loadStreamerDelay: Int64 = 1
    let rangeMonitor = Double(range)
    var listStreamer: [String : AnyObject] = [:]
    let noStreamer = "No Streamer available"
    let noStreamService = "Streame Service Not Available"
    var streamerAccept: Bool = false
    var streamerResponse: Bool = false
    var role: Bool = false //false as viewwer, true as streamer
    var streamerResponseCheckInterval = Timer()
    var viewerRequestCheckInterval = Timer()
    var uidPickedStreamer = String()
    var uidRole = String()
    let segueIdentifier = "toStreamView"
    
    @IBAction func rejectRequest(_ sender: UIButton) {
       self.streamerResponse = false
        self.visibleStreamerResponeButton(false)
    }
    
    @IBAction func acceptRequest(_ sender: UIButton) {
        self.streamerResponse = true
    }
   

    
    
    @IBOutlet weak var progressView: UIProgressView! 
    @IBOutlet weak var loadPercentage: UILabel!
    @IBOutlet weak var ratePrice: UILabel!
    @IBAction func requestBut(_ sender: AnyObject) {
      
        self.role = false
        self.uidRole = ""
        self.streamerResponseCheckInterval.invalidate() // invalidate every time press Request Button --> make simple.
        self.streamerAccept = false
        let aPickedStreamer = self.returnSelectStreamer(self.listStreamer as NSDictionary)
        
        if (aPickedStreamer.allValues.count != 0) {
            /*
             do something to make notificaiton to streamer, if streamer accept do this step, else get another streamer.
             now just connect and stream no matter what streamer agree
             */
            self.uidPickedStreamer = ((aPickedStreamer)["uid"] as? String)!
            print("picker uid:\(self.uidPickedStreamer)")
             // --> need to fire some Notification to Streamer to accept start streaming serivce.
            //  now will create some transaction in DB with id is streamerUID
            
            if !(self.streamerAccept) { // no streamer Accept.
                print("start to send request to Streamer")
                self.sendRequestToStreamer()
                
                self.streamerResponseCheckInterval = Timer.scheduledTimer(timeInterval: Double(fiveSecond), target: self, selector: #selector(self.checkStreamerResponse), userInfo: nil, repeats: true)
                
                self.checkStreamerResponseAfterInterval(30)
                
           
              
 
                
            }
        }
    }
    
    func sendRequestToStreamer() { //write to DB as send request to Streamer
        let transactionRef = self.ref.child("transaction")
        let transactionRequestData: NSDictionary = ["accept": false, self.user!.uid: ["lat": self.requestServiceMarker.position.latitude, "long": self.requestServiceMarker.position.longitude]]
        transactionRef.child(self.uidPickedStreamer).observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.value is NSNull { // mean no request to streamer yet
                print("push request to DB and wait streamer response")
                transactionRef.child(self.uidPickedStreamer).setValue(transactionRequestData)
       
            }
        })
    }
    
    func checkStreamerResponseAfterInterval(_ interval: Int32) {
        
         
         let when = DispatchTime.now() + Double(interval) // delay 30 seconds
         DispatchQueue.main.asyncAfter(deadline: when) {
            if !(self.streamerAccept) { //after 30s check again if no streamer accept
                print("stop check streamer response after \(interval) interval")
                //fire some Notification that no streamer accept to start stream
                self.streamerResponseCheckInterval.invalidate()
            }
            
         }
 
        
        
           }
   
    func checkStreamerResponse() { //run every 5s in 30s
        //var isToStreamView: Bool = false
        let transactionRef = self.ref.child("transaction")
        transactionRef.child(self.uidPickedStreamer).child("accept").observeSingleEvent(of: .value, with: { snapshot in
            if !(snapshot.value is NSNull) { //not null
                let streamerResponse = snapshot.value as! Bool
                print("streamResponse: \(streamerResponse)")
                if !(streamerResponse) { // streamer not response yet. continue to check
                    print("waiting for streamer response")
                } else { // streamer already reponse accept
                    self.streamerResponseCheckInterval.invalidate()
                    self.streamerAccept = true
                
                    print("streamer accept AND move to StreamView as Viewer")
                    transactionRef.child(self.uidPickedStreamer).removeValue()
                    self.role = false // move to StreamView as Viewer
                    self.uidRole = self.uidPickedStreamer
                    //isToStreamView = true
                    //print("isToStreamView in closure as Viewer:\(isToStreamView)")
                    self.performSegue(withIdentifier: self.segueIdentifier, sender: nil)
                    //move to StreamView as Viewer
                    /*
                     As viewer:
                     - join conference with ID is streamerID
                     - connect to streamer with ID is self.uidPickedStreamer.
                    */
                    
                    
                }

                }
            })
      
        
    }
    func checkViewerRequest() {
        //var isToStreamView: Bool = false
        let transactionRef = self.ref.child("transaction")
        transactionRef.child(self.user!.uid).child("accept").observeSingleEvent(of: .value, with: { snapshot in
            if !(snapshot.value is NSNull) { //there are request for user as Streamer
                //self.viewerRequestCheckInterval.invalidate()
                
                //let viewerRequest = snapshot.value as! Int
                //print("viewer request:\(viewerRequest)")
                self.visibleStreamerResponeButton(true)
                transactionRef.child(self.user!.uid).child("accept").setValue(self.streamerResponse)
                if (self.streamerResponse) {
                    self.role = true
                    self.uidRole = self.user!.uid
                    //isToStreamView = true
                    //print("isToStreamView in closure as Streamer:\(isToStreamView)")
                    self.performSegue(withIdentifier: self.segueIdentifier, sender: nil)
                    
                } else {
                    print("reject viewer request")
                }
                
            
            
            }
        })
            }
    
    func checkViewerRequestAfterInterval(_ interval: Int32) {
        self.viewerRequestCheckInterval = Timer.scheduledTimer(timeInterval: Double(interval), target: self, selector: #selector(self.checkViewerRequest), userInfo: nil, repeats: true)
    }
   
    
    func returnSelectStreamer(_ listStreamer: NSDictionary) -> NSDictionary {
        var selectStreamer = NSDictionary()
        
        
        if (listStreamer.allValues.count != 0) { // there is a streamer which not have self viewer (filter at loadMarkerOnMap)
           
            /* do some algorithm to select streamer. now just pick first streamer
            NEVER return uid of self if user request streamer in the user's area
            */
            selectStreamer = listStreamer.allValues.first as! NSDictionary
            print("select list streamer:\(selectStreamer)")
            
        } else {
            self.showNotification(self.loadStreamerDelay, text: noStreamer) // no streamer is available at this location  --> fire immediately
        }
        return selectStreamer
    }
    
    
    func showNotification(_ sec: Int64, text: String) {
        self.notification.text = text
        self.notification.isEnabled = true
        //self.notification.textColor = UIColor.blueColor()
        //self.view.bringSubviewToFront(self.notification)
        self.notification.isHidden = false
        
        let when = DispatchTime.now() + Double(sec) //
        DispatchQueue.main.asyncAfter(deadline: when) {
        }
        
     
       
    }
    
    func visibleStreamerResponeButton(_ visible: Bool) {
        if (visible) {
            self.acceptRequest.isHidden = false
            self.rejectRequest.isHidden = false
            
        } else {
            self.acceptRequest.isHidden = true
            self.rejectRequest.isHidden = true
        }
    }
    
    func updateProgressView() {
        if self.loadMapPercentage <= 100 {
            self.loadPercentage.text = "\(self.loadMapPercentage) %"
            self.progressView.setProgress((Float(self.loadMapPercentage)/100.0), animated: true)
            self.loadMapPercentage += 1
        }
    }
    
    func initalLocationService() {
        
        locationManager.delegate = self
        self.locationManager.startUpdatingLocation()
    }
    
    func delegateMapView() {
        
        mapView.delegate = self
    }
    
    func createFrame() -> CGRect {
        let widthSize = self.view.bounds.width
        let heightSize = self.view.bounds.height //- self.ratePrice.frame.height - CGFloat(self.requestButHeight)
        let frame = CGRect.init(x:0, y:0, width: widthSize, height: heightSize)
        return frame
    }
    
    func executeInitializeMapView(_ sec: Int64) {
        self.notification.isEnabled = false
        var loadMapProgress = Timer()
        loadMapProgress = Timer.scheduledTimer(timeInterval: (Double(fiveSecond)/100), target: self, selector: #selector(self.updateProgressView), userInfo: nil, repeats: true)
        
       
        let when = DispatchTime.now() + Double(sec) //
        DispatchQueue.main.asyncAfter(deadline: when) {
            loadMapProgress.invalidate()
            self.initializeMapView()
            self.loadStreamerMarkerOnMap()
            }

    }
    
    func getLocation() -> CLLocationCoordinate2D {
        if (Int(self.userLocation.coordinate.latitude) == 0) && (Int(self.userLocation.coordinate.longitude) == 0) {
            self.frequencyUpdate = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.getLocation), userInfo: nil, repeats: true)
        } else {
            self.frequencyUpdate.invalidate()
            
            
        }
        
        return self.userLocation.coordinate
    }
    
    func createCamera(_ coordinate: CLLocationCoordinate2D) -> GMSCameraPosition {
        
        let camera = GMSCameraPosition.camera(withTarget: coordinate, zoom: self.oneKmZoom )
        return camera
    }
    
    func clearMarker() {
        self.requestServiceMarker.appearAnimation = kGMSMarkerAnimationNone
    }
    
    func makeMarker(_ position: CLLocationCoordinate2D, snippetString: String, isDraggable: Bool, opacity: Float) -> GMSMarker {
        let marker = GMSMarker()
        marker.position = position
        marker.snippet = snippetString
        marker.appearAnimation = kGMSMarkerAnimationPop
        marker.isDraggable = isDraggable
        marker.map = self.mapView
        marker.opacity = opacity
        return marker
    }
    
    func createMapView(_ frame: CGRect, camera: GMSCameraPosition) {
    
        self.mapView = GMSMapView.map(withFrame: self.createFrame(), camera: camera)
        self.delegateMapView()
        self.view.addSubview(self.mapView)
        self.view.sendSubview(toBack: self.mapView)
    }
    
    func initializeMapView() { //create current user location
        
        self.progressView.isHidden = true
        self.loadPercentage.isHidden = true
        let positionViewer = self.getLocation()
        let camera = self.createCamera(positionViewer)
        self.createMapView(self.createFrame(), camera: camera)
        self.mapView.settings.myLocationButton = true
        self.mapView.isMyLocationEnabled = false
        self.requestServiceMarker = self.makeMarker(positionViewer, snippetString: "Your Location", isDraggable: true, opacity: 1)
    }
  
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = manager.location
        self.userLocation = location!
        
    }
    
    func locationManager(_ _manager: CLLocationManager, didFailWithError error: Error){
    }
    

    
    func dismissKeyboard() { view.endEditing(true) }
    
    
    func mapView(_ mapView: GMSMapView, didChange cameraPosition: GMSCameraPosition) {
    }
    func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
    }
    
    func mapView(_ mapView: GMSMapView, didBeginDragging marker: GMSMarker) {
        self.notification.isHidden = true
        
    }
    func mapView(_ mapView: GMSMapView, didDrag marker: GMSMarker) {
   
       
    }
    
    func mapView(_ mapView: GMSMapView, didEndDragging marker: GMSMarker){ //need press and hold to drag marker
        self.mapView.clear()
        self.requestServiceMarker = marker
        self.requestServiceMarker.map = self.mapView
        self.loadStreamerMarkerOnMap()
        
    }
    
    func mapView(_ mapView: GMSMapView, idleAt cameraPosition: GMSCameraPosition) { self.cameraPosition = cameraPosition  }


    
    func loadStreamerMarkerOnMap() {
        let requestLocationRef = self.ref.child("placeLocation")
        let requestLat = Double(round(self.requestServiceMarker.position.latitude * self.rangeMonitor)/self.rangeMonitor)
        let requestLong = Double(round(self.requestServiceMarker.position.longitude * self.rangeMonitor)/self.rangeMonitor)
        //print("self marker pos:\(self.viewerMarker.position)")
        let stringRequestLat = String(format: "%g", requestLat*self.rangeMonitor)
        let stringRequestLong = String(format: "%g", requestLong*self.rangeMonitor)
        requestLocationRef.child(stringRequestLat).child(stringRequestLong).observeSingleEvent(of: .value, with: { snapshot in
            if snapshot.value is NSNull { // no streamer  --> return no value
                
                self.showNotification(self.delayExecute, text: self.noStreamer)
                self.listStreamer = [:]
                
                
            } else { // there are some streamers --> load streamers
                //self.listStreamer = (snapshot.value! as? NSDictionary)!
                for streamer in (snapshot.value! as? NSDictionary)!{
                    
                    let aUID = streamer.key as? String
                    if (aUID != String(self.user!.uid)) {
                        let aStreamer = streamer.value as? NSDictionary
                        self.listStreamer.updateValue(aStreamer!, forKey: aUID!)
                        var aStreamMarker = GMSMarker()
                        let aMarkerLat = Double(((aStreamer!["lat"] as AnyObject).doubleValue)!)
                        let aMarkerLong = Double(((aStreamer!["long"] as AnyObject).doubleValue)!)
                        let aPosition = CLLocationCoordinate2D(latitude: aMarkerLat, longitude: aMarkerLong)
                        aStreamMarker = self.makeMarker(aPosition, snippetString: "\(aUID)", isDraggable: false, opacity: 1.0)
                        aStreamMarker.icon = GMSMarker.markerImage(with: UIColor.black)
                    }
                }
                if (self.listStreamer.isEmpty) {
                    self.showNotification(3, text: self.noStreamer)
                }
            }
            }
        )
       
        
    }
    
    override var shouldAutorotate : Bool { return false }
    
    override func viewDidAppear(_ animated: Bool) {
        // Do any additional setup after loading the view, typically from a nib
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        view.addGestureRecognizer(tap) // to dismiss keyboard when tap anywhere
      
        self.initalLocationService()
        self.executeInitializeMapView(self.delayExecute)
        self.checkViewerRequestAfterInterval(fiveSecond)
              
        
        
    }
    override func prepare(for segue: (UIStoryboardSegue!), sender: Any!) {
        if segue.identifier == self.segueIdentifier {
            let svc = segue!.destination as! StreamViewController;
            
            svc.role = self.role
            svc.partnerID = self.uidRole           
            
            
        }
    }
    
    
}

