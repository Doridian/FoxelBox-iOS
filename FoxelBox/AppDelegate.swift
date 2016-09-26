//
//  AppDelegate.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    static let chatPoller = ChatPollService()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self])
        
        UITableViewCell.appearance().backgroundColor = UIColor.black
        
        let bgColorView = UIView()
        bgColorView.backgroundColor = UIColor.purple
        UITableViewCell.appearance().selectedBackgroundView = bgColorView
        
        UITabBar.appearance().tintColor = UIColor.purple
        UITextField.appearance().tintColor = UIColor.purple
        UIBarButtonItem.appearance().tintColor = UIColor.purple
        
        AppDelegate.chatPoller.start()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
    }   

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppDelegate.chatPoller.stop()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AppDelegate.chatPoller.start()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        
    }


}

