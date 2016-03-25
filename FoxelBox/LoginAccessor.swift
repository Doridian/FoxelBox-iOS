//
//  LoginAccessor.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import Foundation
import KeychainAccess

protocol LoginReceiver: class {
    func loginStateChanged()
}

class LoginAccessor: APIAccessor {
    internal var sessionToken: String?
    var expiresAt: Int = 0
    
    private var username :String?
    private var password :String?
    
    let loginDispatchGroup = dispatch_group_create()
    
    var refreshId = 0
    var lastActionWasRefresh = false
    
    let loginReceiversLock = NSLock()
    var loginReceivers: NSHashTable = NSHashTable.weakObjectsHashTable()
    
    let keychain = Keychain(service: "com.foxelbox.FoxelBox")
        .synchronizable(true)
        .accessibility(.WhenUnlocked)
    
    override init() {
        super.init()
        self.loadCredentials()
    }
    
    func getUsername() -> String? {
        return self.username
    }
    
    func isLoggedIn() -> Bool {
        dispatch_group_wait(self.loginDispatchGroup, DISPATCH_TIME_FOREVER)
        return self.sessionToken != nil && self.expiresAt > Int(NSDate().timeIntervalSince1970)
    }
    
    func hasCredentials() -> Bool {
        return self.username != nil && self.password != nil
    }
    
    override func onSuccess(response: BaseResponse) throws {
        let myResponse = try LoginResponse(response.result!)
        
        self.refreshId += 1
        let myRefreshId = self.refreshId
        
        self.sessionToken = myResponse.sessionId
        self.expiresAt = myResponse.expiresAt
        
        dispatch_group_leave(loginDispatchGroup)
        
        let expiresIn = self.expiresAt - Int(NSDate().timeIntervalSince1970)
        
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, Int64(expiresIn - 60) * Int64(NSEC_PER_SEC)
            ), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
                if (self.refreshId == myRefreshId) {
                    self.refreshLogin()
                }
        }
    }
    
    override func makeToastForErrors() -> Bool {
        return false
    }
    
    override func onError(message: BaseResponse) {
        if message.statusCode == APIAccessor.STATUS_CANCELLED {
            dispatch_group_leave(self.loginDispatchGroup)
            return
        }
        
        if self.lastActionWasRefresh && message.statusCode == 401 {
            self.sessionToken = nil
            self.doLogin(true)
            dispatch_group_leave(self.loginDispatchGroup)
            return
        }

        dispatch_group_leave(self.loginDispatchGroup)
        
        self.sessionToken = nil
        
        if message.statusCode == 401 {
            self.logout(clearChat: false)
            self.askLogin("Error: \(message.message!)")
            return
        }
        
        super.onError(message)
    }
    
    func loadCredentials() {
        dispatch_group_enter(self.loginDispatchGroup)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            self.username = NSUserDefaults.standardUserDefaults().stringForKey("username")
            if self.username != nil {
                self.password = self.keychain["fbchat"]
            }
            dispatch_group_leave(self.loginDispatchGroup)
        }
    }
    
    func saveCredentials() {
        dispatch_group_enter(self.loginDispatchGroup)
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            NSUserDefaults.standardUserDefaults().setObject(self.username, forKey: "username")
            self.keychain["fbchat"] = self.password
            dispatch_group_leave(self.loginDispatchGroup)
        }
    }
    
    private func loginStateChanged() {
        loginReceiversLock.lock()
        for receiver in self.loginReceivers.objectEnumerator() {
            (receiver as! LoginReceiver).loginStateChanged()
        }
        loginReceiversLock.unlock()
    }
    
    var loginDialogShowing :Bool = false
    
    func askLogout() {
        dispatch_async(dispatch_get_main_queue()) {
            guard !self.loginDialogShowing else {
                return
            }
            
            self.loginDialogShowing = true
            
            let alert = UIAlertController(title: "Log out?", message: "You will need to log in again to send chat", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: .Default) { action in
                self.loginDialogShowing = false
                self.logout()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel) { action in
                self.loginDialogShowing = false
            })
            UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        }
    }
    
    func askLogin(message: String?=nil) {
        self.sessionToken = nil
        
        var showMessage = message
        if showMessage == nil {
            showMessage = "Please use the same credentials as you do on foxelbox.com"
        }
        
        dispatch_async(dispatch_get_main_queue(), {
            guard !self.loginDialogShowing else {
                return
            }
            
            self.loginDialogShowing = true
            
            let alert = UIAlertController(title: "Please log in", message: showMessage, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Default) { action in
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                    self.login(alert.textFields![0].text, password: alert.textFields![1].text) { response in
                        if !response.success {
                            self.askLogin("Error: \(response.message!) (\(response.statusCode))")
                        }
                    }
                    self.loginDialogShowing = false
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel) { action in
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                    self.loginDialogShowing = false
                    self.logout(true, clearChat: self.username != nil)
                }
            })
            alert.addTextFieldWithConfigurationHandler({ textField in
                textField.placeholder = "Username"
                textField.secureTextEntry = false
                textField.text = self.username
            })
            alert.addTextFieldWithConfigurationHandler({ textField in
                textField.placeholder = "Password"
                textField.secureTextEntry = true
                textField.text = self.password
            })
            UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
        })
    }
    
    func login(username :String?, password :String?, callback: ((BaseResponse) -> (Void))?=nil) {
        if self.username != nil && self.username != username {
            AppDelegate.chatPoller.clear()
        }
        
        if username == "" {
            self.username = nil
        } else {
            self.username = username
        }
        if password == "" {
            self.password = nil
        } else {
            self.password = password
        }
        
        if self.username == nil || self.password == nil {
            logout(clearChat: false)
            callback?(BaseResponse(message: "Empty username/password"))
            return
        }
        
        self.sessionToken = nil
        self.saveCredentials()
        
        self.doLogin() { response in
            if response.success {
                self.loginStateChanged()
            }
            callback?(response)
        }
        
        return
    }
    
    func logout(unsetUsername :Bool=false, clearChat :Bool=true) {
        if unsetUsername {
            self.username = nil
        }
        self.password = nil
        self.sessionToken = nil
        self.cancel(true)
        
        self.saveCredentials()
        
        self.loginStateChanged()
        
        if clearChat {
            AppDelegate.chatPoller.clear()
        }
    }
    
    func doLogin(ignoreLoggedIn: Bool=false, succeedOnNoCredentials: Bool=false, callback: ((BaseResponse) -> (Void))?=nil) {
        guard self.hasCredentials() else {
            if succeedOnNoCredentials {
                callback?(BaseResponse(message: "OK", statusCode: 200, success: true))
            } else {
                callback?(BaseResponse(message: "No credentials present"))
            }
            return
        }
        
        guard ignoreLoggedIn || !self.isLoggedIn() else {
            callback?(BaseResponse(message: "OK", statusCode: 200, success: true))
            return
        }

        dispatch_group_enter(self.loginDispatchGroup)
        
        self.cancel(true)
        self.lastActionWasRefresh = false
        
        request("/login", method: "POST", parameters: [
            "username": self.username!,
            "password": self.password!
            ], noSession: true, waitOnLogin: false, callback: callback)
    }
    
    private func refreshLogin() {
        if self.sessionToken == nil {
            self.doLogin()
            return
        }

        dispatch_group_enter(self.loginDispatchGroup)
        
        self.cancel(true)
        self.lastActionWasRefresh = true
        
        request("/login/refresh", method: "POST", waitOnLogin: false)
        return
    }
    
    internal func addReceiver(receiver: LoginReceiver) {
        self.loginReceiversLock.lock()
        self.loginReceivers.addObject(receiver)
        self.loginReceiversLock.unlock()
    }
    
    internal func removeReceiver(receiver: LoginReceiver) {
        self.loginReceiversLock.lock()
        self.loginReceivers.removeObject(receiver)
        self.loginReceiversLock.unlock()
    }
}