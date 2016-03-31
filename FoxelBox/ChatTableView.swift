//
//  ChatTableDelegate.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

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
            self.formatted = ChatStyler.formatMessage(
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
        
        let textWeNeed = self.messageForIndexPath(indexPath).format()
        let textLabel = cell.subviews[0].subviews[0] as! UITextView
        guard textLabel.attributedText != textWeNeed else {
            return cell
        }
        textLabel.attributedText = textWeNeed
        
        guard textLabel.textContainerInset != UIEdgeInsetsZero else {
            return cell
        }
        
        textLabel.linkTextAttributes = [:]
        textLabel.textContainerInset = UIEdgeInsetsZero
        
        let tapGestureRecognizer = UITapGestureRecognizer()
        textLabel.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.addTarget(self, action: #selector(textTapped))
        
        cell.transform = CGAffineTransformMakeScale(1, -1)
        
        return cell
    }
    
    static let parseFunctionRegex = try! NSRegularExpression(pattern: "^(.+)\\('(.+)'\\)$",
                                                             options: [])
    
    func textTapped(recognizer :UITapGestureRecognizer) {
        let textView = recognizer.view as! UITextView
        
        let layoutManager = textView.layoutManager
        let location = recognizer.locationInView(textView)
        // We do not need to subtract insets as those are always 0!
        
        let charIndex = layoutManager.characterIndexForPoint(location, inTextContainer: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        guard charIndex < textView.textStorage.length else {
            return
        }
        
        var range = NSRange()
        
        guard let val = textView.textStorage.attribute(NSLinkAttributeName, atIndex: charIndex, effectiveRange: &range) else {
            return
        }
        let urlVal = val as! NSURL
        
        let urlString = urlVal.absoluteString
        
        guard let result = ChatTableView.parseFunctionRegex.firstMatchInString(urlString, options: [], range: NSRange(location: 0, length: urlString.characters.count)) else {
            return
        }
        
        let function = (urlString as NSString).substringWithRange(result.rangeAtIndex(1))
        let argument = (urlString as NSString).substringWithRange(result.rangeAtIndex(2))
                        .stringByRemovingPercentEncoding!
        
        let chatViewController = self.getChatViewController()

        switch function {
        case "suggest_command":
            chatViewController.setChatMessage(argument)
        case "run_command":
            chatViewController.rawSendChatMessage(argument)
        case "open_url":
            if let url = NSURL(string: argument) {
                UIApplication.sharedApplication().openURL(url)
            }
        default:
            break
        }
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let text = self.messageForIndexPath(indexPath).format()
        let rect = text.boundingRectWithSize(CGSize(width: tableView.bounds.width, height: 0), options:NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
        
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
    
    func getChatViewController() -> ChatViewController {
        return (self.nextResponder()?.nextResponder() as! ChatViewController)
    }
    
    func setBadgeValue(badge :String?) {
        self.getChatViewController().navigationController?.tabBarItem.badgeValue = badge
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