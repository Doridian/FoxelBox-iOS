//
//  ChatPollService.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import Foundation

protocol ChatReceiver: class {
    func addMessages(_ messages: [ChatMessageOut])
    func clearMessages()
}

protocol ChatErrorReceiver: class {
    func setPollError(_ message :String?)
}

class ChatPollService: APIAccessor, LoginReceiver {
    internal static let MAX_MESSAGES = 100
    
    var maxID :Int = -1
    var chatReceivers: NSHashTable<AnyObject> = NSHashTable.weakObjects()
    var lateChatReceivers: NSHashTable<AnyObject> = NSHashTable.weakObjects()
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
    
    override func onSuccess(_ response: BaseResponse) throws {
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
            self.chatHistory.append(contentsOf: myResponse.messages)
            
            if self.chatHistory.count > ChatPollService.MAX_MESSAGES {
                self.chatHistory.removeFirst(self.chatHistory.count - ChatPollService.MAX_MESSAGES)
            }
        }
        
        self.chatHistoryLock.unlock()
        
        self.schedulePollNow()
    }
    
    override func onError(_ message: BaseResponse) {
        super.onError(message)
        
        self.shortPollNext = true
        self.pollScheduled = 0
        
        if message.statusCode != 401 && message.statusCode != APIAccessor.STATUS_CANCELLED {
            self.errorReceiver?.setPollError("Error fetching messages: \(message.message!) (\(message.statusCode))")
        }
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.utility).asyncAfter(
            deadline: DispatchTime.now() + Double(1 * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
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
    
    internal func addReceiver(_ receiver: ChatReceiver, sendHistory: Bool, isLate: Bool=false) {
        self.chatHistoryLock.lock()
        
        if isLate {
            self.lateChatReceivers.add(receiver)
        } else {
            self.chatReceivers.add(receiver)
        }
            
        if sendHistory && self.chatHistory.count > 0 {
            let chatHistoryCopy = [ChatMessageOut](self.chatHistory)
            self.chatHistoryLock.unlock()
            receiver.addMessages(chatHistoryCopy)
        } else {
            self.chatHistoryLock.unlock()
        }
    }
    
    internal func removeReceiver(_ receiver: ChatReceiver) {
        self.chatHistoryLock.lock()
        self.chatReceivers.remove(receiver)
        self.lateChatReceivers.remove(receiver)
        self.chatHistoryLock.unlock()
    }
    
    func loginStateChanged() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            self.start()
        }
    }
}
