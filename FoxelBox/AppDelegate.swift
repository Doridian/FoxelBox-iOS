//
//  AppDelegate.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    static let chatPoller = ChatPollService()
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        UITableViewCell.appearance().backgroundColor = UIColor.blackColor()
        
        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.purpleColor()
        UITableViewCell.appearance().selectedBackgroundView = bgColorView
        
        UITabBar.appearance().tintColor = UIColor.purpleColor()
        UITextField.appearance().tintColor = UIColor.purpleColor()
        UIBarButtonItem.appearance().tintColor = UIColor.purpleColor()
        
        AppDelegate.chatPoller.start()
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        
    }   

    func applicationDidEnterBackground(application: UIApplication) {
        AppDelegate.chatPoller.stop()
    }

    func applicationWillEnterForeground(application: UIApplication) {
        AppDelegate.chatPoller.start()
    }

    func applicationDidBecomeActive(application: UIApplication) {
        
    }

    func applicationWillTerminate(application: UIApplication) {
        
    }


}

