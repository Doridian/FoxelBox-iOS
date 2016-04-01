//
//  LegalViewController.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 01/04/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit
import DTCoreText

class LegalViewController: UIViewController {
    @IBOutlet weak var legalTextView: UITextView!
    
    static let nsHTMLParseOptions: [String: AnyObject] = [
        NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
        NSCharacterEncodingDocumentAttribute: NSUTF8StringEncoding,
        DTDefaultFontName: "Helvetica",
        DTDefaultFontSize: 10,
        DTDefaultTextColor: "white",
        DTDefaultLinkDecoration: false,
        DTDefaultLinkColor: "white",
        DTDefaultLinkHighlightColor: "white",
        DTDefaultFontFamily: "Helvetica",
        DTUseiOS6Attributes: true
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let resPath = NSURL(fileURLWithPath: NSBundle.mainBundle().resourcePath!)
            .URLByAppendingPathComponent("Legal.html")

        let str = NSData(contentsOfURL: resPath)

        self.legalTextView.attributedText = DTHTMLAttributedStringBuilder(HTML: str, options: LegalViewController.nsHTMLParseOptions, documentAttributes: nil).generatedAttributedString()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.legalTextView.setContentOffset(CGPoint.zero, animated: false)
    }
}