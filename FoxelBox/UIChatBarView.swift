//
//  UIChatBarView.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit

class UIChatBarView: UIView {
    var upperBorder: CALayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if upperBorder != nil {
            upperBorder!.removeFromSuperlayer()
        }
        
        upperBorder = CALayer()
        upperBorder!.backgroundColor = UIColor.grayColor().CGColor
        upperBorder!.frame = CGRectMake(0, 0, self.frame.width, 1.0)
        self.layer.addSublayer(upperBorder!)
    }
}
