//
//  LoginAccessor.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import Foundation
import KeychainAccess
import Crashlytics

protocol LoginReceiver: class {
    func loginStateChanged()
}

class LoginAccessor: APIAccessor {
    internal var sessionToken: String?
    var expiresAt: Int = 0
    
    fileprivate var username :String?
    fileprivate var password :String?
    fileprivate var passwordChanged :Bool = false
    
    let loginDispatchGroup = DispatchGroup()
    
    var refreshId = 0
    var lastActionWasRefresh = false
    
    let loginReceiversLock = NSLock()
    var loginReceivers: NSHashTable<AnyObject> = NSHashTable.weakObjects()
    
    let keychain = Keychain(server: "https://foxelbox.com", protocolType: .https)
        .synchronizable(true)
    
    override init() {
        super.init()
        self.loadCredentials()
    }
    
    func getUsername() -> String? {
        return self.username
    }
    
    func isLoggedIn() -> Bool {
        self.loginDispatchGroup.wait(timeout: DispatchTime.distantFuture)
        return self.sessionToken != nil && self.expiresAt > Int(Date().timeIntervalSince1970)
    }
    
    func hasCredentials() -> Bool {
        return self.username != nil && self.password != nil
    }
    
    override func onSuccess(_ response: BaseResponse) throws {
        let myResponse = try LoginResponse(response.result!)
        
        self.refreshId += 1
        let myRefreshId = self.refreshId
        
        self.sessionToken = myResponse.sessionId
        self.expiresAt = myResponse.expiresAt
        
        loginDispatchGroup.leave()
        
        let expiresIn = self.expiresAt - Int(Date().timeIntervalSince1970)
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(expiresIn - 60) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                if (self.refreshId == myRefreshId) {
                    self.refreshLogin()
                }
        }
    }
    
    override func makeToastForErrors() -> Bool {
        return false
    }
    
    override func onError(_ message: BaseResponse) {
        if message.statusCode == APIAccessor.STATUS_CANCELLED {
            self.loginDispatchGroup.leave()
            return
        }
        
        if self.lastActionWasRefresh && message.statusCode == 401 {
            self.sessionToken = nil
            self.doLogin(true)
            self.loginDispatchGroup.leave()
            return
        }

        self.loginDispatchGroup.leave()
        
        self.sessionToken = nil
        
        if message.statusCode == 401 {
            self.logout(clearChat: false)
            self.askLogin("Error: \(message.message!)")
            return
        }
        
        super.onError(message)
    }
    
    func loadCredentials() {
        self.loginDispatchGroup.enter()
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            self.username = UserDefaults.standard.string(forKey: "username")
            if self.username != nil {
                self.password = self.keychain[self.username!]
            }
            self.loginDispatchGroup.leave()
        }
    }
    
    func saveCredentials() {
        self.loginDispatchGroup.enter()
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            let oldUsername = UserDefaults.standard.string(forKey: "username")
            UserDefaults.standard.set(self.username, forKey: "username")
            
            if oldUsername != nil && oldUsername != self.username {
                self.keychain[oldUsername!] = nil
            }
            
            if self.username != nil {
                self.keychain[self.username!] = self.password
            }
            
            self.loginDispatchGroup.leave()
        }
    }
    
    fileprivate func loginStateChanged() {
        loginReceiversLock.lock()
        for receiver in self.loginReceivers.objectEnumerator() {
            (receiver as! LoginReceiver).loginStateChanged()
        }
        loginReceiversLock.unlock()
    }
    
    var loginDialogShowing :Bool = false
    
    func askLogout() {
        DispatchQueue.main.async {
            guard !self.loginDialogShowing else {
                return
            }
            
            self.loginDialogShowing = true
            
            let alert = UIAlertController(title: "Log out?", message: "You will need to log in again to send chat", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Confirm", style: .default) { action in
                self.loginDialogShowing = false
                self.logout()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                self.loginDialogShowing = false
            })
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        }
    }
    
    fileprivate func tryLoginAskOnError(_ username: String?, password: String?) {
        self.login(username, password: password) { response in
            if !response.success {
                self.askLogin("Error: \(response.message!) (\(response.statusCode))")
            }
        }
    }
    
    func askLogin(_ message: String?=nil) {
        self.sessionToken = nil
        
        self.loginDialogShowing = true
        self.keychain.getSharedPassword() { (username, password, error) in
            self.loginDialogShowing = false
            
            if error != nil {
                print("Keychain error: \(error!)")
            }
            
            if username == nil || password == nil || error != nil {
                self.askLoginOwn(message)
            } else {
                self.tryLoginAskOnError(username, password: password)
            }
        }
    }
    
    func askLoginOwn(_ message: String?=nil) {
        var showMessage = message
        if showMessage == nil {
            showMessage = "Please use the same credentials as you do on foxelbox.com"
        }
        
        DispatchQueue.main.async(execute: {
            guard !self.loginDialogShowing else {
                return
            }
            
            self.loginDialogShowing = true
            
            let alert = UIAlertController(title: "Please log in", message: showMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { action in
                DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
                    self.tryLoginAskOnError(alert.textFields![0].text, password: alert.textFields![1].text)
                    self.loginDialogShowing = false
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { action in
                DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
                    self.loginDialogShowing = false
                    self.logout(true, clearChat: self.username != nil)
                }
            })
            alert.addTextField(configurationHandler: { textField in
                textField.placeholder = "Username"
                textField.isSecureTextEntry = true
                textField.text = self.username
            })
            alert.addTextField(configurationHandler: { textField in
                textField.placeholder = "Password"
                textField.isSecureTextEntry = true
                textField.text = self.password
            })
            UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
        })
    }
    
    func login(_ username :String?, password :String?, callback: ((BaseResponse) -> (Void))?=nil) {
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
        
        self.passwordChanged = true
        
        if self.username == nil || self.password == nil {
            logout(clearChat: false)
            callback?(BaseResponse(message: "Empty username/password"))
            return
        }
        
        Crashlytics.sharedInstance().setUserName(self.username)
        Crashlytics.sharedInstance().setUserIdentifier(nil)
        
        self.sessionToken = nil
        
        self.doLogin(callback: callback)
        
        return
    }
    
    func logout(_ unsetUsername :Bool=false, clearChat :Bool=true) {
        if unsetUsername {
            self.username = nil
            Crashlytics.sharedInstance().setUserName(nil)
        }
        
        Crashlytics.sharedInstance().setUserIdentifier(nil)
        
        self.password = nil
        self.sessionToken = nil
        self.cancel(true)
        
        self.saveCredentials()
        
        self.loginStateChanged()
        
        if clearChat {
            AppDelegate.chatPoller.clear()
        }
    }
    
    func doLogin(_ ignoreLoggedIn: Bool=false, succeedOnNoCredentials: Bool=false, callback: ((BaseResponse) -> (Void))?=nil) {
        guard ignoreLoggedIn || !self.isLoggedIn() else {
            callback?(BaseResponse(message: "OK", statusCode: 200, success: true))
            return
        }
        
        guard self.hasCredentials() else {
            if succeedOnNoCredentials {
                callback?(BaseResponse(message: "OK", statusCode: 200, success: true))
            } else {
                callback?(BaseResponse(message: "No credentials present"))
            }
            return
        }

        self.loginDispatchGroup.enter()
        
        self.cancel(true)
        self.lastActionWasRefresh = false
        
        request("/login", method: "POST", parameters: [
            "username": self.username!,
            "password": self.password!
        ], noSession: true, waitOnLogin: false) { response in
            if response.success {
                Crashlytics.sharedInstance().setUserIdentifier(self.username)
                
                self.loginStateChanged()
                self.saveCredentials()
            } else {
                Crashlytics.sharedInstance().setUserIdentifier(nil)
            }
            callback?(response)
        }
    }
    
    fileprivate func refreshLogin() {
        if self.sessionToken == nil {
            self.doLogin()
            return
        }

        self.loginDispatchGroup.enter()
        
        self.cancel(true)
        self.lastActionWasRefresh = true
        
        request("/login/refresh", method: "POST", waitOnLogin: false)
        return
    }
    
    internal func addReceiver(_ receiver: LoginReceiver) {
        self.loginReceiversLock.lock()
        self.loginReceivers.add(receiver)
        self.loginReceiversLock.unlock()
    }
    
    internal func removeReceiver(_ receiver: LoginReceiver) {
        self.loginReceiversLock.lock()
        self.loginReceivers.remove(receiver)
        self.loginReceiversLock.unlock()
    }
}
