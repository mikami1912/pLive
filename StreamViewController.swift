
//
//  StreamViewController.swift
//  pLive
//
//  Created by Duy Truong on 10/5/16.
//  Copyright © 2016 Self. All rights reserved.
//
import Firebase
import TwilioVideo

class StreamViewController: UIViewController {
    var partnerID = String()
    var conferenceID = String()
    var userIDShort = String()
    var user = FIRAuth.auth()?.currentUser
    
    var role = Bool() //false as Viewer , true as streamer

    /*
     There are 2 ways client get access token:
     - generate manually from Twilio console (based on account profile for each client) --> this is for testing
     - client request owner service server (not Twilio) to get token. Server will call rest API to Twilio to generate token and send back to client
     
     */
    //default accessToken.
    var accessToken = "ACCESS_TOKEN"
    
    // Configure remote URL to fetch token from
   var tokenUrl = "http://plive.co/authorize.php"
    
    //View create
    var remoteView: UIView?
    var previewView: UIView?
    
    let screenRatio: CGFloat = 2/3
    let screenratioLeft: CGFloat = 1/3
    
    // Video SDK components
    var client: TVIVideoClient?
    var room: TVIRoom?
    var localMedia: TVILocalMedia?
    var camera: TVICameraCapturer?
    var localVideoTrack: TVILocalVideoTrack?
    var localAudioTrack: TVILocalAudioTrack?
    var participant: TVIParticipant?
    
    
    @IBAction func endButton(_ sender: AnyObject) {
        self.cleanupRemoteParticipant()
        
    }
    
    func initialView() {
        remoteView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height*(screenRatio))) //for viewer only
        previewView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height*(screenRatio))) // for streamer only
        
        if (!role) { self.view.addSubview(remoteView!) }
        else { self.view.addSubview(previewView!) }
        
        if PlatformUtils.isSimulator {
            self.previewView?.removeFromSuperview()
        } else {
            // Preview our local camera track in the local video preview view.
            self.startPreview()
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
        
    }
    func dismissKeyboard() {
        /*
         if (self.roomTextField.isFirstResponder) {
         self.roomTextField.resignFirstResponder()
         }
         */
    }
    
    
    func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }
        // Preview our local camera track in the local video preview view.
        camera = TVICameraCapturer()
        localVideoTrack = localMedia?.addVideoTrack(true, capturer: camera!)
        if (localVideoTrack == nil) {
            logMessage(messageText: "Failed to add video track")
            
        }
        else {
            // Attach view to video track for local preview
            localVideoTrack!.attach(self.previewView!)
            
            logMessage(messageText: "Video track added to localMedia")
            
            
            // We will flip camera on tap.
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.flipCamera))
            self.previewView?.addGestureRecognizer(tap)
        }
        
    }
    
    func flipCamera() {
        if (self.camera?.source == .frontCamera) {
            self.camera?.selectSource(.backCameraWide)
        } else {
            self.camera?.selectSource(.frontCamera)
        }
    }
    
    func prepareLocalMedia() {
        
        // We will offer local audio and video when we connect to room.
        
        // Adding local audio track to localMedia
        if (localAudioTrack == nil) {
            localAudioTrack = localMedia?.addAudioTrack(true)
        }
        
        // Adding local video track to localMedia and starting local preview if it is not already started.
        if (localMedia?.videoTracks.count == 0) {
            self.startPreview()
        }
    }
    
    func initializeService() {
        
        // LocalMedia represents the collection of tracks that we are sending to other Participants from our VideoClient.
        self.localMedia = TVILocalMedia()
        
        let audioController = localMedia?.audioController
        audioController?.audioOutput = .videoChatDefault
        
        self.initializeRoom()
        self.initialView()
        tokenUrl = tokenUrl + "?username=" + userIDShort
        logMessage(messageText: tokenUrl)
        
    }
    func showRoomUI(inRoom: Bool) {
        /*
         self.connectButton.isHidden = inRoom
         self.roomTextField.isHidden = inRoom
         self.roomLine.isHidden = inRoom
         self.roomLabel.isHidden = inRoom
         self.micButton.isHidden = !inRoom
         self.disconnectButton.isHidden = !inRoom
         */
        UIApplication.shared.isIdleTimerDisabled = inRoom
    }
    
    func initializeRoom() {
        self.userIDShort = self.user!.uid[self.user!.uid.startIndex..<self.user!.uid.index(self.user!.uid.startIndex, offsetBy: 6)] //take first 6 chars of userID
        
        if (self.role) { // true --> as streamer
            self.conferenceID = self.userIDShort // take first 6 chars of streamerID (this case is self.user)
            
        } else { //false --> as Viewer
            self.conferenceID = partnerID[partnerID.startIndex..<partnerID.index(partnerID.startIndex, offsetBy: 6)] // take first 6 chars of StreamerID
           
        }
    }
    
    
    func connectService() {
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
        if (accessToken == "ACCESS_TOKEN") {
            do {
                accessToken = try TokenUtils.fetchToken(url: tokenUrl)
                print("accessToken from Server: \(accessToken)");
            } catch {
                
                let message = "Failed to fetch access token"
                logMessage(messageText: message)
                
                
                return
            }
        }
        
       
        
        
        // Create a Client with the access token that we fetched (or hardcoded).
        if (client == nil) {
            client = TVIVideoClient(token: accessToken)
            
            if (client == nil) {
                
                logMessage(messageText: "Failed to create video client")
                
                return
            }
        }
        
        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()
        
        // Preparing the connect options
        let connectOptions = TVIConnectOptions { (builder) in
            
            // Use the local media that we prepared earlier.
            builder.localMedia = self.localMedia
            
            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.name = self.conferenceID
        }
        
        // Connect to the Room using the options we provided.
        room = client?.connect(with: connectOptions, delegate: self)
     
        
        logMessage(messageText: "Attempting to connect to room \(self.conferenceID)")
        //print("attempt to connect the room: \(self.conferenceID)")
        self.showRoomUI(inRoom: true)
        
    }
    
    func logMessage(messageText: String) {
        print(messageText)
    }
    
    func cleanupRemoteParticipant() {
        if ((self.participant) != nil) {
            if ((self.participant?.media.videoTracks.count)! > 0) {
                self.participant?.media.videoTracks[0].detach(self.remoteView!)
            }
        }
        self.participant = nil
    }
    
    
    override var shouldAutorotate : Bool { return false }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initializeService()
        self.connectService()
    }
}




// MARK: TVIRoomDelegate
extension StreamViewController : TVIRoomDelegate {
    func didConnect(to room: TVIRoom) {
        
        // At the moment, this example only supports rendering one Participant at a time.
        
        logMessage(messageText: "Connected to room \(room.name) as \(room.localParticipant?.identity)")
        
        if (room.participants.count > 0) {
            self.participant = room.participants[0]
            self.participant?.delegate = self
        }
    }
    
    func room(_ room: TVIRoom, didDisconnectWithError error: Error?) {
        logMessage(messageText: "Disconncted from room \(room.name), error = \(error)")
        
        self.cleanupRemoteParticipant()
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func room(_ room: TVIRoom, didFailToConnectWithError error: Error) {
        logMessage(messageText: "Failed to connect to room with error")
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func room(_ room: TVIRoom, participantDidConnect participant: TVIParticipant) {
        if (self.participant == nil) {
            self.participant = participant
            self.participant?.delegate = self
        }
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) connected")
    }
    
    func room(_ room: TVIRoom, participantDidDisconnect participant: TVIParticipant) {
        if (self.participant == participant) {
            cleanupRemoteParticipant()
        }
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")
    }
}

// MARK: TVIParticipantDelegate
extension StreamViewController : TVIParticipantDelegate {
    func participant(_ participant: TVIParticipant, addedVideoTrack videoTrack: TVIVideoTrack) {
        logMessage(messageText: "Participant \(participant.identity) added video track")
        
        if (self.participant == participant) {
            videoTrack.attach(self.remoteView!)
        }
    }
    
    func participant(_ participant: TVIParticipant, removedVideoTrack videoTrack: TVIVideoTrack) {
        logMessage(messageText: "Participant \(participant.identity) removed video track")
        
        if (self.participant == participant) {
            videoTrack.detach(self.remoteView!)
        }
    }
    
    func participant(_ participant: TVIParticipant, addedAudioTrack audioTrack: TVIAudioTrack) {
        logMessage(messageText: "Participant \(participant.identity) added audio track")
        
    }
    
    func participant(_ participant: TVIParticipant, removedAudioTrack audioTrack: TVIAudioTrack) {
        logMessage(messageText: "Participant \(participant.identity) removed audio track")
    }
    
    func participant(_ participant: TVIParticipant, enabledTrack track: TVITrack) {
        var type = ""
        if (track is TVIVideoTrack) {
            type = "video"
        } else {
            type = "audio"
        }
        logMessage(messageText: "Participant \(participant.identity) enabled \(type) track")
    }
    
    func participant(_ participant: TVIParticipant, disabledTrack track: TVITrack) {
        var type = ""
        if (track is TVIVideoTrack) {
            type = "video"
        } else {
            type = "audio"
        }
        logMessage(messageText: "Participant \(participant.identity) disabled \(type) track")
    }
}



