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

class ChatStyler : NSObject, XMLParserDelegate {
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
    
    fileprivate func fixTags(_ msg :String) throws -> String {
        let xmlData = ("<span>" + msg + "</span>").data(using: String.Encoding.utf8)
        let xmlParser = XMLParser(data: xmlData!)
        xmlParser.delegate = self
        xmlParser.parse()

        return "<span>" + returnData + "</span>"
    }
    
    var isSurroundedByA: [Bool] = [Bool]()
    
    @objc func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        if let onClick = attributeDict["onClick"] {
            returnData += "<a href=\"" + onClick
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)! + "\">"
            isSurroundedByA.append(true)
        } else {
            isSurroundedByA.append(false)
        }
        
        if elementName == "color" {
            returnData += "<font color=\"" + ChatStyler.colorReplacements[attributeDict["name"]!]! + "\">"
        }
    }
    
    @objc func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "color" {
            returnData += "</font>"
        }
        
        if isSurroundedByA.popLast()! {
            returnData += "</a>"
        }
    }
    
    @objc func parser(_ parser: XMLParser, foundCharacters string: String) {
        returnData += string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    static let nsHTMLParseOptions: [String: AnyObject] = [
        NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType as AnyObject,
        NSCharacterEncodingDocumentAttribute: String.Encoding.utf8 as AnyObject,
        DTDefaultFontName: "Helvetica" as AnyObject,
        DTDefaultFontSize: 14 as AnyObject,
        DTDefaultTextColor: "white" as AnyObject,
        DTDefaultLinkDecoration: false as AnyObject,
        DTDefaultLinkColor: "white" as AnyObject,
        DTDefaultLinkHighlightColor: "white" as AnyObject,
        DTUseiOS6Attributes: true as AnyObject
    ]
    
    static func formatMessage(_ msg: String) -> NSAttributedString {
        do {
            let instance = ChatStyler()
            let data: Data = try instance.fixTags(msg).data(using: String.Encoding.utf8)!
            return DTHTMLAttributedStringBuilder(html: data, options: nsHTMLParseOptions, documentAttributes: nil).generatedAttributedString()
        } catch let error {
            print("Error: \(error)")
            let dataNo = msg.data(using: String.Encoding.utf8)
            return try! NSAttributedString(data: dataNo!, options: [:], documentAttributes: nil)
        }
    }
}
