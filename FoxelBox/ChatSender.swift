//
//  ChatAccessor.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import Foundation

class ChatSender: APIAccessor, ChatReceiver {
    static let instance = ChatSender()
    
    let pendingMessagesLock = NSLock()
    var pendingMessages = NSMutableSet()
    
    override init() {
        super.init()
        AppDelegate.chatPoller.addReceiver(self, sendHistory: false, isLate: true)
    }
    
    deinit {
        AppDelegate.chatPoller.removeReceiver(self)
    }
    
    fileprivate func messageDone(_ context: JSONUUID) {
        guard self.pendingMessages.contains(context) else {
            return
        }
        
        self.pendingMessagesLock.lock()
        
        APIAccessor.incrementRequestsInProgress(-1)
        self.pendingMessages.remove(context)
        
        self.pendingMessagesLock.unlock()
    }
    
    func addMessages(_ messages: [ChatMessageOut]) {
        for message in messages {
            guard message.finalizeContext else {
                continue
            }
            
            self.messageDone(message.context)
        }
    }
    
    func clearMessages() {
        pendingMessagesLock.lock()
        
        APIAccessor.incrementRequestsInProgress(-pendingMessages.count)
        pendingMessages.removeAllObjects()
        
        pendingMessagesLock.unlock()
    }
    
    override func onSuccess(_ response: BaseResponse) throws {
        let reply = try SentMessageReply(response.result!)
        
        self.pendingMessagesLock.lock()
        
        self.pendingMessages.add(reply.context)
        APIAccessor.incrementRequestsInProgress(1)
        
        let delayTime = DispatchTime.now() + Double(Int64(10 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).asyncAfter(deadline: delayTime) {
            self.messageDone(reply.context)
        }
        
        self.pendingMessagesLock.unlock()
    }
    
    override func onError(_ response: BaseResponse) {
        super.onError(response)
    }
    
    internal func sendMessage(_ message: String, callback: ((BaseResponse) -> (Void))?=nil) {
        request("/message", method: "POST", parameters: ["message": message], callback: callback)
    }
}
