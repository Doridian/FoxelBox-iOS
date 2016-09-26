//
//  UIEventedTabBarController.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 26/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

class UIEventedTabBarController: UITabBarController, UITabBarControllerDelegate {
    weak var lastViewController :UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        self.lastViewController = self.selectedViewController
    }
    
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if viewController == self.lastViewController {
            var ourViewController = viewController
            if viewController is UINavigationController {
                ourViewController = viewController.childViewControllers[0]
            }
            
            if ourViewController is MapViewController {
                (ourViewController as! MapViewController).reload()
            } else if ourViewController is ChatViewController {
                (ourViewController as! ChatViewController).scrollToBottom()
            }
        }
        
        self.lastViewController = viewController
    }
}
