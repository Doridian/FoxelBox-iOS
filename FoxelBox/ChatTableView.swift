//
//  ChatTableDelegate.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit
import DTCoreText

class ChatTableView: UITableView, UITableViewDelegate, UITableViewDataSource, ChatReceiver {
    private static let MAX_MESSAGES = 100
    
    private class CachingMessage {
        let message :ChatMessageOut
        var formatted :NSAttributedString?
        
        init(message :ChatMessageOut) {
            self.message = message
        }
        
        func format() -> NSAttributedString {
            if self.formatted != nil {
                return self.formatted!
            }
            self.formatted = ChatStyler.instance.formatMessage(
                self.message.contents!
            )
            return self.formatted!
        }
    }
    
    private var messagesArray: [CachingMessage] = [CachingMessage]()
    
    var lastYOffset: CGFloat = 0
    var autoScrolling = true
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.delegate = self
        self.dataSource = self
        
        self.transform = CGAffineTransformMakeScale(1, -1)
        
        AppDelegate.chatPoller.addReceiver(self, sendHistory: true)
    }
    
    deinit {
        AppDelegate.chatPoller.removeReceiver(self)
    }
    
    private func messageForIndexPath(indexPath: NSIndexPath) -> CachingMessage {
        return self.messagesArray[(self.messagesArray.count - 1) - indexPath.row]
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messagesArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MessageCell")! as UITableViewCell
        
        let textLabel = cell.subviews[0].subviews[0] as! DTAttributedLabel
        textLabel.edgeInsets = UIEdgeInsetsZero
        textLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        textLabel.attributedString = self.messageForIndexPath(indexPath).format()
        
        cell.transform = CGAffineTransformMakeScale(1, -1)
        
        return cell
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let text = self.messageForIndexPath(indexPath).format()
        let rect = text.boundingRectWithSize(CGSize(width: self.bounds.width, height: 0), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
        
        return rect.height
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if self.contentOffset.y == 0 {
            self.setBadgeValue(nil)
        }
    }
    
    func scrollToBottom() {
        self.setContentOffset(CGPoint.zero, animated: true)
    }
    
    func setBadgeValue(badge :String?) {
        (self.nextResponder()?.nextResponder() as! UIViewController).navigationController?.tabBarItem.badgeValue = badge
    }
    
    func addMessages(messages: [ChatMessageOut]) {
        var myMessages = [ChatMessageOut]()
        
        for message in messages {
            guard message.type == "text" else {
                continue
            }
            myMessages.append(message)
        }
        
        if myMessages.count > ChatTableView.MAX_MESSAGES {
            myMessages.removeFirst(myMessages.count - ChatTableView.MAX_MESSAGES)
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            let messagesAdded = myMessages.count
            
            let messagesRemoved = self.messagesArray.count - ChatPollService.MAX_MESSAGES
            
            if messagesRemoved > 0 {
                self.messagesArray.removeFirst(messagesRemoved)
            }
            
            if self.contentOffset.y > 0 {
                self.setBadgeValue("!")
            }
            
            self.beginUpdates()
            
            if messagesRemoved > 0 {
                var removePaths: [NSIndexPath] = [NSIndexPath]()
                
                let lastIndex = self.messagesArray.count
                
                for i in lastIndex...(lastIndex + messagesRemoved - 1) {
                    removePaths.append(NSIndexPath(forRow: i, inSection: 0))
                }
                
                self.deleteRowsAtIndexPaths(removePaths, withRowAnimation: UITableViewRowAnimation.Top)
            }
            
            for message in myMessages {
                self.messagesArray.append(CachingMessage(message: message))
            }
            
            if messagesAdded > 0 {
                var insertPaths: [NSIndexPath] = [NSIndexPath]()
                
                for i in 0...(messagesAdded - 1) {
                    insertPaths.append(NSIndexPath(forRow: i, inSection: 0))
                }
                
                self.insertRowsAtIndexPaths(insertPaths, withRowAnimation: UITableViewRowAnimation.Top)
            }
            
            self.endUpdates()
        }
    }
    
    func clearMessages() {
        dispatch_async(dispatch_get_main_queue(), {
            self.setBadgeValue(nil)
            self.messagesArray.removeAll()
            self.reloadData()
        })
    }
}