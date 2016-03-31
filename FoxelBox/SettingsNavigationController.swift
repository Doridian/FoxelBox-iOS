//
//  SettingsNavigationController.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 01/04/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

class SettingsNavigationController: UINavigationController {
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        (segue.destinationViewController as! LegalViewController).legalText = sender as? String
    }
}
