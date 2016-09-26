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
        
        NotificationCenter.default.addObserver(self, selector: #selector(ChatViewController.keyboardWillChangeFrame(_:)), name:NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)

        self.CHAT_BAR_BASE_HEIGHT = self.chatBarHeightConstraint.constant
        self.CHAT_TEXT_BASE_COLOR = self.chatTextField.textColor
        self.CHAT_TEXT_DISABLED_COLOR = UIColor.darkGray
        
        self.chatSendButton.setTitleColor(UIColor.darkGray, for: UIControlState.disabled)
        
        self.chatMessageTableView.rowHeight = UITableViewAutomaticDimension
        self.chatMessageTableView.estimatedRowHeight = 20
        
        self.chatTextField.delegate = self
        
        self.chatTextField.attributedPlaceholder = NSAttributedString(string: self.chatTextField.placeholder!, attributes: [NSForegroundColorAttributeName:UIColor.lightGray])

        APIAccessor.loginUtil.addReceiver(self)
        self.loginStateChanged()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        APIAccessor.loginUtil.removeReceiver(self)
        
        if let errorReceiver = AppDelegate.chatPoller.errorReceiver {
            if errorReceiver is ChatViewController && (errorReceiver as! ChatViewController) == self {
                AppDelegate.chatPoller.errorReceiver = nil
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.sendChatMessage(textField)
        return true
    }
    
    func setChatMessage(_ message: String) {
        guard self.canSendChat else {
            return
        }
        
        self.chatTextField.text = message
        self.chatTextField.becomeFirstResponder()
    }
    
    @IBAction func sendChatMessage(_ sender: AnyObject) {
        let chatMessage = self.chatTextField.text
        guard chatMessage != nil && chatMessage != "" else {
            return
        }
        
        self.rawSendChatMessage(chatMessage!)
    }
    
    func rawSendChatMessage(_ chatMessage: String) {
        guard self.canSendChat else {
            return
        }
        
        self.isSendingMessage = true
        self.loginStateChanged()
        ChatSender.instance.sendMessage(chatMessage) { response in
            self.isSendingMessage = false
            self.loginStateChanged()
            DispatchQueue.main.async {
                if response.success {
                    self.chatTextField.text = ""
                }
            }
        }
    }
    
    func setPollError(_ message :String?) {
        DispatchQueue.main.async {
            self.pollErrorLabel.text = message
            
            UIView.animate(withDuration: 0.5, animations: {
                self.pollErrorView.isHidden = (message == nil)
            }) 
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if !self.canSendChat {
            return false
        }
        
        let currentCharacterCount = textField.text?.characters.count ?? 0
        
        // Prevent the text field crashing by editing outside of its own range
        if (range.length + range.location > currentCharacterCount) {
            return false
        }
        
        // Prevent the text field from growing above 240 characters
        return ((currentCharacterCount - range.length) + string.characters.count) <= 240
    }
    
    func loginStateChanged() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
            let enabled = (!self.isSendingMessage) && APIAccessor.loginUtil.hasCredentials()
            
            self.canSendChat = enabled
            
            DispatchQueue.main.async {
                self.chatSendButton.isEnabled = enabled
                
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
    
    func keyboardWillChangeFrame(_ notification: Notification) {
        let info = (notification as NSNotification).userInfo!
        
        let animationDuration = (info[UIKeyboardAnimationDurationUserInfoKey]! as AnyObject).doubleValue
        
        let keyboardFrameEnd: CGRect = self.view.convert((info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue, from: nil)
        
        var offsetHeight = (self.view.bounds.size.height - keyboardFrameEnd.origin.y) + (self.chatBarView.frame.maxY - self.view.frame.maxY)
        if offsetHeight < 0 {
            offsetHeight = 0
        }
        self.chatBarHeightConstraint.constant = self.CHAT_BAR_BASE_HEIGHT + offsetHeight
        
        UIView.animate(withDuration: animationDuration!, animations: {
            self.view.layoutIfNeeded()
        }) 
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
}

