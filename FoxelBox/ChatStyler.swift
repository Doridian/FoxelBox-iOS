//
//  ChatStyler.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import Foundation
import UIKit
import DTCoreText

class ChatStyler {
    var tagReplacements: [String: String] = [String: String]()
    
    init() {
        addColor("black", color: "#000000")
        addColor("dark_blue", color: "#0000BE")
        addColor("dark_green", color: "#00BE00")
        addColor("dark_aqua", color: "#00BEBE")
        addColor("dark_red", color: "#BE0000")
        addColor("dark_purple", color: "#BE00BE")
        addColor("gold", color: "#D9A334")
        addColor("gray", color: "#BEBEBE")
        addColor("dark_gray", color: "#3F3F3F")
        addColor("blue", color: "#3F3FFE")
        addColor("green", color: "#3FFE3F")
        addColor("aqua", color: "#3FFEFE")
        addColor("red", color: "#FE3F3F")
        addColor("light_purple", color: "#FE3FFE")
        addColor("yellow", color: "#FEFE3F")
        addColor("white", color: "#FFFFFF")
        tagReplacements["</color>"] = "</font>"
    }
    
    private func addColor(name: String, color: String) {
        tagReplacements["<color name=\"\(name)\">"] = "<font color=\"\(color)\">"
    }
    
    private func fixTags(msg :String) -> String {
        var moddedMsg = msg
        for (k, v) in tagReplacements {
            moddedMsg = moddedMsg.stringByReplacingOccurrencesOfString(k, withString: v)
        }
        return moddedMsg
    }
    
    let nsHTMLParseOptions: [String: AnyObject] = [
        NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
        NSCharacterEncodingDocumentAttribute: NSUTF8StringEncoding,
        DTDefaultFontName: "Helvetica",
        DTDefaultFontSize: 14,
        DTDefaultTextColor: "white",
        DTDefaultLinkDecoration: false,
        DTDefaultLinkColor: "white",
        DTUseiOS6Attributes: true
    ]
    
    func formatMessage(msg: String) -> NSAttributedString {
        let data: NSData = ("<span>" + fixTags(msg) + "</span>").dataUsingEncoding(NSUTF8StringEncoding)!
        return DTHTMLAttributedStringBuilder(HTML: data, options: nsHTMLParseOptions, documentAttributes: nil).generatedAttributedString()
    }
    
    static let instance = ChatStyler()
}