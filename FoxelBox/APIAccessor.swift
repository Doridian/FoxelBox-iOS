//
//  APIAccessor.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import SwiftHTTP
import JSONJoy
import UIKit
import JLToast

class APIAccessor {
    static let API_URL = "https://api.foxelbox.com/v2"
    static let STATUS_CANCELLED = -999
    static let STATUS_TIMEOUT = -1001
    
    static let STATUS_SESSIONERROR = 597
    
    static let loginUtil = LoginAccessor()
    
    private static var requestsInProgress = 0
    private static var progressIndicatorShowing = false
    
    static func incrementRequestsInProgress(val: Int) {
        dispatch_async(dispatch_get_main_queue()) {
            APIAccessor.requestsInProgress += val
            let progressIndicatorShouldShow = APIAccessor.requestsInProgress > 0
            if progressIndicatorShouldShow != APIAccessor.progressIndicatorShowing {
                UIApplication.sharedApplication().networkActivityIndicatorVisible = progressIndicatorShouldShow
                APIAccessor.progressIndicatorShowing = progressIndicatorShouldShow
            }
        }
    }
    
    private var lastRequest: HTTP?
    func cancel(wait: Bool=false) -> Bool {
        guard self.lastRequest != nil else {
            return false
        }
        self.lastRequest?.cancel()
        if wait {
            self.waitUntilFinished()
        }
        return true
    }
    
    func waitUntilFinished() {
        self.lastRequest?.waitUntilFinished()
    }
    
    func isLongpoll() -> Bool {
        return false
    }
    
    func makeToastForErrors() -> Bool {
        return true
    }
    
    func onSuccess(response: BaseResponse) throws {
        // Implement in children!
    }
    
    func onError(response: BaseResponse) {
        if (response.statusCode == 401) {
            APIAccessor.loginUtil.logout()
            APIAccessor.loginUtil.askLogin()
            return
        }
        
        let textMessage = "HTTP error: \(response.message!) (\(response.statusCode))"
        print(textMessage)
        if self.makeToastForErrors() {
            JLToast.makeText(textMessage, duration: 1).show()
        }
    }
    
    func request(url: String, method: String, parameters: [String: String]?=nil, noSession: Bool=false, waitOnLogin: Bool=false, loginOptional: Bool=false, callback: ((BaseResponse) -> (Void))?=nil) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            self.doRequest(url, method: method, parameters: parameters, noSession: noSession, waitOnLogin: waitOnLogin, loginOptional: loginOptional, callback: callback)
        }
    }
    
    private func doRequest(url: String, method: String, parameters: [String: String]?=nil, noSession: Bool=false, waitOnLogin: Bool=true, loginOptional: Bool=false, callback: ((BaseResponse) -> (Void))?=nil) {
        do {
            let req = NSMutableURLRequest(urlString: APIAccessor.API_URL + url)!
            
            req.HTTPMethod = method
            
            if waitOnLogin {
                APIAccessor.loginUtil.doLogin(succeedOnNoCredentials: loginOptional) { response in
                    guard response.success else {
                        self.onError(response)
                        callback?(response)
                        return
                    }
                    self.request(url, method: method, parameters: parameters, noSession: noSession, waitOnLogin: false, loginOptional: loginOptional, callback: callback)
                }
                return
            }
            
            if !noSession && APIAccessor.loginUtil.sessionToken != nil {
                req.setValue(APIAccessor.loginUtil.sessionToken!, forHTTPHeaderField: "Authorization")
            }
            
            let thisLongpoll = self.isLongpoll()
            
            if thisLongpoll {
                try req.appendParameters(["longPoll": "true"])
                req.timeoutInterval = 30
            } else {
                req.timeoutInterval = 5
            }
            
            if parameters != nil {
                try req.appendParameters(parameters!)
            }
            
            if !thisLongpoll {
                APIAccessor.incrementRequestsInProgress(1)
            }
            
            let opt = HTTP(req)
            self.lastRequest = opt
            opt.start { response in
                self.lastRequest = nil
                
                var jsonResponse: BaseResponse
                do {
                    jsonResponse = try BaseResponse(JSONDecoder(response.data))
                    if jsonResponse.success {
                        try self.onSuccess(jsonResponse)
                    } else {
                        self.onError(jsonResponse)
                    }
                } catch let error {
                    if response.error != nil {
                        jsonResponse = BaseResponse(message: response.error!.localizedDescription, statusCode: response.error!.code)
                    } else {
                        jsonResponse = BaseResponse(message: String(error))
                    }
                    
                    self.onError(jsonResponse)
                }
                
                callback?(jsonResponse)
                
                if !thisLongpoll {
                    APIAccessor.incrementRequestsInProgress(-1)
                }
            }
        } catch let error {
            self.onError(BaseResponse(message: "Internal error: \(error)"))
        }
    }
}