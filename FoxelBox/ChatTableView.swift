//
//  ChatTableDelegate.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

class ChatTableView: UITableView, UITableViewDelegate, UITableViewDataSource, ChatReceiver {
    fileprivate static let MAX_MESSAGES = 100
    
    fileprivate class CachingMessage {
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
    
    fileprivate var messagesArray: [CachingMessage] = [CachingMessage]()
    fileprivate var lastBadgeValue :String?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.delegate = self
        self.dataSource = self
        
        self.transform = CGAffineTransform(scaleX: 1, y: -1)
        
        AppDelegate.chatPoller.addReceiver(self, sendHistory: true)
    }
    
    deinit {
        AppDelegate.chatPoller.removeReceiver(self)
    }
    
    fileprivate func messageForIndexPath(_ indexPath: IndexPath) -> CachingMessage {
        return self.messagesArray[(self.messagesArray.count - 1) - (indexPath as NSIndexPath).row]
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messagesArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell")! as UITableViewCell
        
        let textWeNeed = self.messageForIndexPath(indexPath).format()
        let textLabel = cell.subviews[0].subviews[0] as! UITextView
        guard textLabel.attributedText != textWeNeed else {
            return cell
        }
        textLabel.attributedText = textWeNeed
        
        guard textLabel.textContainerInset != UIEdgeInsets.zero else {
            return cell
        }
        
        textLabel.linkTextAttributes = [:]
        textLabel.textContainerInset = UIEdgeInsets.zero
        
        let tapGestureRecognizer = UITapGestureRecognizer()
        textLabel.addGestureRecognizer(tapGestureRecognizer)
        tapGestureRecognizer.addTarget(self, action: #selector(textTapped))
        
        cell.transform = CGAffineTransform(scaleX: 1, y: -1)
        
        return cell
    }
    
    static let parseFunctionRegex = try! NSRegularExpression(pattern: "^(.+)\\('(.+)'\\)$",
                                                             options: [])
    
    func textTapped(_ recognizer :UITapGestureRecognizer) {
        let textView = recognizer.view as! UITextView
        
        let layoutManager = textView.layoutManager
        let location = recognizer.location(in: textView)
        // We do not need to subtract insets as those are always 0!
        
        let charIndex = layoutManager.characterIndex(for: location, in: textView.textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        
        guard charIndex < textView.textStorage.length else {
            return
        }
        
        var range = NSRange()
        
        guard let val = textView.textStorage.attribute(NSLinkAttributeName, at: charIndex, effectiveRange: &range) else {
            return
        }
        let urlVal = val as! URL
        
        let urlString = urlVal.absoluteString
        
        guard let result = ChatTableView.parseFunctionRegex.firstMatch(in: urlString, options: [], range: NSRange(location: 0, length: urlString.characters.count)) else {
            return
        }
        
        let function = (urlString as NSString).substring(with: result.rangeAt(1))
        let argument = (urlString as NSString).substring(with: result.rangeAt(2))
                        .removingPercentEncoding!
        
        let chatViewController = self.getChatViewController()

        switch function {
        case "suggest_command":
            chatViewController.setChatMessage(argument)
        case "run_command":
            chatViewController.rawSendChatMessage(argument)
        case "open_url":
            if let url = URL(string: argument) {
                UIApplication.shared.openURL(url)
            }
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        let text = self.messageForIndexPath(indexPath).format()
        let rect = text.boundingRect(with: CGSize(width: tableView.bounds.width, height: 0), options:NSStringDrawingOptions.usesLineFragmentOrigin, context: nil)
        
        return rect.height
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard self.contentOffset.y <= 0 else {
            return
        }
        self.setBadgeValue(nil)
    }
    
    func scrollToBottom() {
        self.setContentOffset(CGPoint.zero, animated: true)
    }
    
    func getChatViewController() -> ChatViewController {
        return (self.next?.next as! ChatViewController)
    }
    
    func setBadgeValue(_ badge :String?) {
        guard self.lastBadgeValue != badge else {
            return
        }
        self.getChatViewController().navigationController?.tabBarItem.badgeValue = badge
        self.lastBadgeValue = badge
    }
    
    func addMessages(_ messages: [ChatMessageOut]) {
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
        
        DispatchQueue.main.async {
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
                var removePaths: [IndexPath] = [IndexPath]()
                
                let lastIndex = self.messagesArray.count
                
                for i in lastIndex...(lastIndex + messagesRemoved - 1) {
                    removePaths.append(IndexPath(row: i, section: 0))
                }
                
                self.deleteRows(at: removePaths, with: UITableViewRowAnimation.top)
            }
            
            for message in myMessages {
                self.messagesArray.append(CachingMessage(message: message))
            }
            
            if messagesAdded > 0 {
                var insertPaths: [IndexPath] = [IndexPath]()
                
                for i in 0...(messagesAdded - 1) {
                    insertPaths.append(IndexPath(row: i, section: 0))
                }
                
                self.insertRows(at: insertPaths, with: UITableViewRowAnimation.top)
            }
            
            self.endUpdates()
        }
    }
    
    func clearMessages() {
        DispatchQueue.main.async(execute: {
            self.setBadgeValue(nil)
            self.messagesArray.removeAll()
            self.reloadData()
        })
    }
}
