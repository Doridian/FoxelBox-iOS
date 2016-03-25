//
//  MapViewController.swift
//  FoxelBox
//
//  Created by Mark Dietzer on 25/03/16.
//  Copyright © 2016 Mark Dietzer. All rights reserved.
//

import UIKit
import WebKit

class MapViewController: UIViewController, WKNavigationDelegate {
    private weak var webView: WKWebView?
    @IBOutlet weak var refreshButton: UIBarButtonItem!
    
    override func loadView() {
        super.loadView()
        
        let webView = WKWebView()
        self.webView = webView
        
        webView.navigationDelegate = self
        
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addConstraints([
            NSLayoutConstraint(
                item:webView,
                attribute:NSLayoutAttribute.Top,
                relatedBy:NSLayoutRelation.Equal,
                toItem:topLayoutGuide,
                attribute:NSLayoutAttribute.Bottom,
                multiplier:1,
                constant:0
            ),
            NSLayoutConstraint(
                item:webView,
                attribute:NSLayoutAttribute.Bottom,
                relatedBy:NSLayoutRelation.Equal,
                toItem:bottomLayoutGuide,
                attribute:NSLayoutAttribute.Top,
                multiplier:1,
                constant:0
            ),
            NSLayoutConstraint(
                item:webView,
                attribute:NSLayoutAttribute.Width,
                relatedBy:NSLayoutRelation.Equal,
                toItem:view,
                attribute:NSLayoutAttribute.Width,
                multiplier:1,
                constant:0
            )
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.reload()
    }
    
    @IBAction func refresh(sender: AnyObject) {
        self.reload()
    }
    
    func reload() {
        let url = NSURL(string: "https://api.foxelbox.com/map/main/")
        let req = NSURLRequest(URL: url!)
        webView?.loadRequest(req)
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return UIStatusBarStyle.LightContent
    }
    
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        APIAccessor.incrementRequestsInProgress(1)
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        APIAccessor.incrementRequestsInProgress(-1)
    }
}

