//
//  ChatViewController.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

class ChatViewController: UIViewController, UITextFieldDelegate, ChatErrorReceiver, LoginReceiver {
    @IBOutlet weak var chatTextField: UITextField!
    @IBOutlet weak var chatBarView: UIChatBarView!
    @IBOutlet weak var chatSendButton: UIButton!
    @IBOutlet weak var chatBarHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var chatMessageTableView: ChatTableView!
    
    @IBOutlet weak var pollErrorView: UIView!
    @IBOutlet weak var pollErrorLabel: UILabel!
    
    var CHAT_BAR_BASE_HEIGHT: CGFloat!
    var CHAT_TEXT_BASE_COLOR: UIColor!
    var CHAT_TEXT_DISABLED_COLOR: UIColor!
    
    var canSendChat = true
    var isSendingMessage = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AppDelegate.chatPoller.errorReceiver = self
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ChatViewController.keyboardWillShowHide(_:)), name:UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ChatViewController.keyboardWillShowHide(_:)), name:UIKeyboardWillHideNotification, object: nil)
        
        self.CHAT_BAR_BASE_HEIGHT = self.chatBarHeightConstraint.constant
        self.CHAT_TEXT_BASE_COLOR = self.chatTextField.textColor
        self.CHAT_TEXT_DISABLED_COLOR = UIColor.darkGrayColor()
        
        self.chatSendButton.setTitleColor(UIColor.darkGrayColor(), forState: UIControlState.Disabled)
        
        self.chatMessageTableView.rowHeight = UITableViewAutomaticDimension
        self.chatMessageTableView.estimatedRowHeight = 20
        
        self.chatTextField.delegate = self
        
        self.chatTextField.attributedPlaceholder = NSAttributedString(string: self.chatTextField.placeholder!, attributes: [NSForegroundColorAttributeName:UIColor.lightGrayColor()])

        APIAccessor.loginUtil.addReceiver(self)
        self.loginStateChanged()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        APIAccessor.loginUtil.removeReceiver(self)
        
        if let errorReceiver = AppDelegate.chatPoller.errorReceiver {
            if errorReceiver is ChatViewController && (errorReceiver as! ChatViewController) == self {
                AppDelegate.chatPoller.errorReceiver = nil
            }
        }
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        self.sendChatMessage(textField)
        return true
    }
    
    func setChatMessage(message: String) {
        guard self.canSendChat else {
            return
        }
        
        self.chatTextField.text = message
        self.chatTextField.becomeFirstResponder()
    }
    
    @IBAction func sendChatMessage(sender: AnyObject) {
        let chatMessage = self.chatTextField.text
        guard chatMessage != nil && chatMessage != "" else {
            return
        }
        
        self.rawSendChatMessage(chatMessage!)
    }
    
    func rawSendChatMessage(chatMessage: String) {
        guard self.canSendChat else {
            return
        }
        
        self.isSendingMessage = true
        self.loginStateChanged()
        ChatSender.instance.sendMessage(chatMessage) { response in
            self.isSendingMessage = false
            self.loginStateChanged()
            dispatch_async(dispatch_get_main_queue()) {
                if response.success {
                    self.chatTextField.text = ""
                }
            }
        }
    }
    
    func setPollError(message :String?) {
        dispatch_async(dispatch_get_main_queue()) {
            self.pollErrorLabel.text = message
            
            UIView.animateWithDuration(0.5) {
                self.pollErrorView.hidden = (message == nil)
            }
        }
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        return self.canSendChat
    }
    
    func loginStateChanged() {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
            let enabled = (!self.isSendingMessage) && APIAccessor.loginUtil.hasCredentials()
            
            self.canSendChat = enabled
            
            dispatch_async(dispatch_get_main_queue()) {
                self.chatSendButton.enabled = enabled
                
                if enabled {
                    self.chatTextField.textColor = self.CHAT_TEXT_BASE_COLOR
                } else {
                    self.chatTextField.textColor = self.CHAT_TEXT_DISABLED_COLOR
                }
            }
        }
    }
    
    func scrollToBottom() {
        self.chatMessageTableView.scrollToBottom()
    }
    
    @IBAction func triggerLoginCheck() {
        guard !APIAccessor.loginUtil.hasCredentials() else {
            return
        }
            
        APIAccessor.loginUtil.askLogin("You need to be logged in to send chat messages")
    }
    
    func keyboardWillShowHide(notification: NSNotification) {
        let info = notification.userInfo!
        
        let keyboardFrameBegin: CGRect = self.view.convertRect((info[UIKeyboardFrameBeginUserInfoKey] as! NSValue).CGRectValue(), fromView: nil)
        let keyboardFrameEnd: CGRect = self.view.convertRect((info[UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue(), fromView: nil)
        
        UIView.animateWithDuration(-1) {
            var offsetHeight = (keyboardFrameBegin.origin.y - keyboardFrameEnd.origin.y) + (self.chatBarView.frame.maxY - self.view.frame.maxY)
            if offsetHeight < 0 {
                offsetHeight = 0
            }
            self.chatBarHeightConstraint.constant = self.CHAT_BAR_BASE_HEIGHT + offsetHeight
            self.view.layoutIfNeeded()
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
}

