//
//  SettingsViewController.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 27/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController, LoginReceiver {
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var usernameLabel: UILabel!
    @IBOutlet weak var logoutLabel: UILabel!
    
    @IBOutlet weak var usernameCell: UITableViewCell!
    @IBOutlet weak var websiteTableCell: UITableViewCell!
    @IBOutlet weak var logoutTableCell: UITableViewCell!
    @IBOutlet weak var legalTableCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let version = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as! String
        let build = NSBundle.mainBundle().infoDictionary?[kCFBundleVersionKey as String] as! String
        
        self.versionLabel.text = "Version: \(version) (\(build))"
        
        self.loginStateChanged()
        APIAccessor.loginUtil.addReceiver(self)
    }
    
    deinit {
        APIAccessor.loginUtil.removeReceiver(self)
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let cell = tableView.cellForRowAtIndexPath(indexPath)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        if cell == websiteTableCell {
            UIApplication.sharedApplication().openURL(NSURL(string: "https://foxelbox.com")!)
        } else if cell == logoutTableCell {
            let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.White);
            spinner.frame = CGRectMake(0, 0, 24, 24);
            self.logoutTableCell.accessoryView = spinner
            
            spinner.startAnimating()
            
            self.logoutTableCell.userInteractionEnabled = false
            
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                if APIAccessor.loginUtil.hasCredentials() {
                    APIAccessor.loginUtil.askLogout()
                } else {
                    APIAccessor.loginUtil.askLogin()
                }
            }
        } else if cell == legalTableCell {
            self.navigationController!.performSegueWithIdentifier("LegalSegue", sender: self)
        }
    }
    
    func loginStateChanged() {
        dispatch_async(dispatch_get_main_queue()) {
            let isLoggedIn = APIAccessor.loginUtil.hasCredentials()
            
            self.logoutTableCell.accessoryView = nil
            self.logoutTableCell.userInteractionEnabled = true
            
            if isLoggedIn {
                self.logoutLabel.textColor = UIColor.redColor()
                self.logoutLabel.text = "Log out"
                self.usernameLabel.textColor = UIColor.whiteColor()
                self.usernameLabel.text = "Username: \(APIAccessor.loginUtil.getUsername()!)"
            } else {
                self.logoutLabel.textColor = UIColor.whiteColor()
                self.logoutLabel.text = "Log in"
                self.usernameLabel.textColor = UIColor.grayColor()
                self.usernameLabel.text = "Not logged in"
            }
        }
    }
}