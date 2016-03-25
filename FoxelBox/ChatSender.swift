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
    
    private func messageDone(context: JSONUUID) {
        guard self.pendingMessages.containsObject(context) else {
            return
        }
        
        self.pendingMessagesLock.lock()
        
        APIAccessor.incrementRequestsInProgress(-1)
        self.pendingMessages.removeObject(context)
        
        self.pendingMessagesLock.unlock()
    }
    
    func addMessages(messages: [ChatMessageOut]) {
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
    
    override func onSuccess(response: BaseResponse) throws {
        let reply = try SentMessageReply(response.result!)
        
        self.pendingMessagesLock.lock()
        
        self.pendingMessages.addObject(reply.context)
        APIAccessor.incrementRequestsInProgress(1)
        
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(10 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            self.messageDone(reply.context)
        }
        
        self.pendingMessagesLock.unlock()
    }
    
    override func onError(response: BaseResponse) {
        super.onError(response)
    }
    
    internal func sendMessage(message: String, callback: ((BaseResponse) -> (Void))?=nil) {
        request("/message", method: "POST", parameters: ["message": message], callback: callback)
    }
}