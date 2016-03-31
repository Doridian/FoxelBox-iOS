//
//  LegalViewController.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 01/04/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

class LegalViewController: UIViewController {
    @IBOutlet weak var legalTextView: UITextView!
    
    var legalText :String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.legalTextView.text = self.legalText
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.legalTextView.setContentOffset(CGPoint.zero, animated: false)
    }
}