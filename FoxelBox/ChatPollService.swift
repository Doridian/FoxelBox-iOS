//
//  ChatPollService.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import Foundation

protocol ChatReceiver: class {
    func addMessages(messages: [ChatMessageOut])
    func clearMessages()
}

protocol ChatErrorReceiver: class {
    func setPollError(message :String?)
}

class ChatPollService: APIAccessor, LoginReceiver {
    internal static let MAX_MESSAGES = 100
    
    var maxID :Int = -1
    var chatReceivers: NSHashTable = NSHashTable.weakObjectsHashTable()
    var lateChatReceivers: NSHashTable = NSHashTable.weakObjectsHashTable()
    var chatHistory: [ChatMessageOut] = [ChatMessageOut]()
    
    var pollScheduled: UInt8 = 0
    var shouldRun: Bool = false
    
    var shortPollNext: Bool = false
    
    let chatHistoryLock = NSLock()
    
    weak var errorReceiver :ChatErrorReceiver?
    
    func stop() {
        self.shouldRun = false
        self.cancel(true)
        
        APIAccessor.loginUtil.removeReceiver(self)
    }
    
    func clear() {
        self.chatHistoryLock.lock()
        for receiver in chatReceivers.objectEnumerator() {
            (receiver as! ChatReceiver).clearMessages()
        }
        for receiver in lateChatReceivers.objectEnumerator() {
            (receiver as! ChatReceiver).clearMessages()
        }
        self.chatHistory.removeAll()
        self.maxID = -1
        self.chatHistoryLock.unlock()
    }
    
    func start() {
        self.stop()
        self.shouldRun = true
        self.shortPollNext = true
        self.schedulePollNow()
        
        APIAccessor.loginUtil.addReceiver(self)
    }
    
    deinit {
        self.stop()
    }
    
    override func isLongpoll() -> Bool {
        return !self.shortPollNext
    }
    
    override func makeToastForErrors() -> Bool {
        return false
    }
    
    override func onSuccess(response: BaseResponse) throws {
        let myResponse = try MessageReply(response.result!)

        self.pollScheduled = 0
        self.shortPollNext = false
        
        self.errorReceiver?.setPollError(nil)
        
        if myResponse.latestId < 1 {
            schedulePollNow()
            return
        }
        
        self.chatHistoryLock.lock()
        
        self.maxID = myResponse.latestId
        
        if myResponse.messages.count > 0 {
            for receiver in chatReceivers.objectEnumerator() {
                (receiver as! ChatReceiver).addMessages(myResponse.messages)
            }
            for receiver in lateChatReceivers.objectEnumerator() {
                (receiver as! ChatReceiver).addMessages(myResponse.messages)
            }
            self.chatHistory.appendContentsOf(myResponse.messages)
            
            if self.chatHistory.count > ChatPollService.MAX_MESSAGES {
                self.chatHistory.removeFirst(self.chatHistory.count - ChatPollService.MAX_MESSAGES)
            }
        }
        
        self.chatHistoryLock.unlock()
        
        self.schedulePollNow()
    }
    
    override func onError(message: BaseResponse) {
        super.onError(message)
        
        self.shortPollNext = true
        self.pollScheduled = 0
        
        if message.statusCode != 401 && message.statusCode != APIAccessor.STATUS_CANCELLED {
            self.errorReceiver?.setPollError("Error fetching messages: \(message.message!) (\(message.statusCode))")
        }
        
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)
        ), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)) {
            self.schedulePollNow()
        }
    }
    
    func schedulePollNow() {
        guard self.shouldRun else {
            return
        }
        
        guard !OSAtomicTestAndSet(0, &self.pollScheduled) else {
            return
        }
        
        self.request("/message", method: "GET", parameters: ["since": String(self.maxID)], waitOnLogin: true, loginOptional: true)
    }
    
    internal func addReceiver(receiver: ChatReceiver, sendHistory: Bool, isLate: Bool=false) {
        self.chatHistoryLock.lock()
        
        if isLate {
            self.lateChatReceivers.addObject(receiver)
        } else {
            self.chatReceivers.addObject(receiver)
        }
            
        if sendHistory && self.chatHistory.count > 0 {
            let chatHistoryCopy = [ChatMessageOut](self.chatHistory)
            self.chatHistoryLock.unlock()
            receiver.addMessages(chatHistoryCopy)
        } else {
            self.chatHistoryLock.unlock()
        }
    }
    
    internal func removeReceiver(receiver: ChatReceiver) {
        self.chatHistoryLock.lock()
        self.chatReceivers.removeObject(receiver)
        self.lateChatReceivers.removeObject(receiver)
        self.chatHistoryLock.unlock()
    }
    
    func loginStateChanged() {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            self.start()
        }
    }
}