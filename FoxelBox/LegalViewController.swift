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
    
    override func loadView() {
        super.loadView()
        
        let resPath = URL(fileURLWithPath: Bundle.main.resourcePath!)
            .appendingPathComponent("Legal.html")

        let str = try? Data(contentsOf: resPath)

        self.legalTextView.attributedText = DTHTMLAttributedStringBuilder(html: str, options: [
            NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
            NSCharacterEncodingDocumentAttribute: String.Encoding.utf8,
            DTDefaultFontName: "Helvetica",
            DTDefaultFontSize: 10,
            DTDefaultTextColor: "white",
            DTDefaultLinkDecoration: false,
            DTDefaultLinkColor: "white",
            DTDefaultLinkHighlightColor: "white",
            DTDefaultFontFamily: "Helvetica",
            DTUseiOS6Attributes: true
            ], documentAttributes: nil).generatedAttributedString()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.legalTextView.setContentOffset(CGPoint.zero, animated: false)
    }
}
