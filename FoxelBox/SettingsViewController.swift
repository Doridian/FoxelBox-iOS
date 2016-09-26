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
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String
        let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as! String
        
        self.versionLabel.text = "Version: \(version) (\(build))"
        
        self.loginStateChanged()
        APIAccessor.loginUtil.addReceiver(self)
    }
    
    deinit {
        APIAccessor.loginUtil.removeReceiver(self)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
        
        if cell == websiteTableCell {
            UIApplication.shared.openURL(URL(string: "https://foxelbox.com")!)
        } else if cell == logoutTableCell {
            let spinner = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.white);
            spinner.frame = CGRect(x: 0, y: 0, width: 24, height: 24);
            self.logoutTableCell.accessoryView = spinner
            
            spinner.startAnimating()
            
            self.logoutTableCell.isUserInteractionEnabled = false
            
            DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
                if APIAccessor.loginUtil.hasCredentials() {
                    APIAccessor.loginUtil.askLogout()
                } else {
                    APIAccessor.loginUtil.askLogin()
                }
            }
        } else if cell == legalTableCell {
            self.navigationController!.performSegue(withIdentifier: "LegalSegue", sender: self)
        }
    }
    
    func loginStateChanged() {
        DispatchQueue.main.async {
            let isLoggedIn = APIAccessor.loginUtil.hasCredentials()
            
            self.logoutTableCell.accessoryView = nil
            self.logoutTableCell.isUserInteractionEnabled = true
            
            if isLoggedIn {
                self.logoutLabel.textColor = UIColor.red
                self.logoutLabel.text = "Log out"
                self.usernameLabel.textColor = UIColor.white
                self.usernameLabel.text = "Username: \(APIAccessor.loginUtil.getUsername()!)"
            } else {
                self.logoutLabel.textColor = UIColor.white
                self.logoutLabel.text = "Log in"
                self.usernameLabel.textColor = UIColor.gray
                self.usernameLabel.text = "Not logged in"
            }
        }
    }
}
