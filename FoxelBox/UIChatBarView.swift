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
        upperBorder!.backgroundColor = UIColor.gray.cgColor
        upperBorder!.frame = CGRect(x: 0, y: 0, width: self.frame.width, height: 1.0)
        self.layer.addSublayer(upperBorder!)
    }
}
