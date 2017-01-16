//
//  AppState.swift
//  pLive
//
//  Created by Duy Truong on 9/14/16.
//  Copyright © 2016 Self. All rights reserved.
//

import Foundation

class AppState: NSObject {
    
    static let sharedInstance = AppState()
    
    var signedIn = false
    var displayName: String?
    var photoUrl: URL?

}
