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

class ChatStyler : NSObject, NSXMLParserDelegate {
    static let colorReplacements = [
        "black": "#000000",
        "dark_blue": "#0000BE",
        "dark_green": "#00BE00",
        "dark_aqua": "#00BEBE",
        "dark_red": "#BE0000",
        "dark_purple": "#BE00BE",
        "gold": "#D9A334",
        "gray": "#BEBEBE",
        "dark_gray": "#3F3F3F",
        "blue": "#3F3FFE",
        "green": "#3FFE3F",
        "aqua": "#3FFEFE",
        "red": "#FE3F3F",
        "light_purple": "#FE3FFE",
        "yellow": "#FEFE3F",
        "white": "#FFFFFF"
    ]
    
    var returnData = ""
    
    private func fixTags(msg :String) throws -> String {
        let xmlData = ("<span>" + msg + "</span>").dataUsingEncoding(NSUTF8StringEncoding)
        let xmlParser = NSXMLParser(data: xmlData!)
        xmlParser.delegate = self
        xmlParser.parse()

        return "<span>" + returnData + "</span>"
    }
    
    var isSurroundedByA: [Bool] = [Bool]()
    
    @objc func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        if let onClick = attributeDict["onClick"] {
            returnData += "<a href=\"" + onClick
                .stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())! + "\">"
            isSurroundedByA.append(true)
        } else {
            isSurroundedByA.append(false)
        }
        
        if elementName == "color" {
            returnData += "<font color=\"" + ChatStyler.colorReplacements[attributeDict["name"]!]! + "\">"
        }
    }
    
    @objc func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "color" {
            returnData += "</font>"
        }
        
        if isSurroundedByA.popLast()!.boolValue {
            returnData += "</a>"
        }
    }
    
    @objc func parser(parser: NSXMLParser, foundCharacters string: String) {
        returnData += string
            .stringByReplacingOccurrencesOfString("&", withString: "&amp;")
            .stringByReplacingOccurrencesOfString("<", withString: "&lt;")
            .stringByReplacingOccurrencesOfString(">", withString: "&gt;")
    }
    
    static let nsHTMLParseOptions: [String: AnyObject] = [
        NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
        NSCharacterEncodingDocumentAttribute: NSUTF8StringEncoding,
        DTDefaultFontName: "Helvetica",
        DTDefaultFontSize: 14,
        DTDefaultTextColor: "white",
        DTDefaultLinkDecoration: false,
        DTDefaultLinkColor: "white",
        DTDefaultLinkHighlightColor: "white",
        DTUseiOS6Attributes: true
    ]
    
    static func formatMessage(msg: String) -> NSAttributedString {
        do {
            let instance = ChatStyler()
            let data: NSData = try instance.fixTags(msg).dataUsingEncoding(NSUTF8StringEncoding)!
            return DTHTMLAttributedStringBuilder(HTML: data, options: nsHTMLParseOptions, documentAttributes: nil).generatedAttributedString()
        } catch let error {
            print("Error: \(error)")
            let dataNo = msg.dataUsingEncoding(NSUTF8StringEncoding)
            return try! NSAttributedString(data: dataNo!, options: [:], documentAttributes: nil)
        }
    }
}