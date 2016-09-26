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
    fileprivate weak var webView: WKWebView?
    
    var inNavigation :UInt8 = 0
    var hasLoaded = false
    
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
                attribute:NSLayoutAttribute.top,
                relatedBy:NSLayoutRelation.equal,
                toItem:topLayoutGuide,
                attribute:NSLayoutAttribute.bottom,
                multiplier:1,
                constant:0
            ),
            NSLayoutConstraint(
                item:webView,
                attribute:NSLayoutAttribute.bottom,
                relatedBy:NSLayoutRelation.equal,
                toItem:bottomLayoutGuide,
                attribute:NSLayoutAttribute.top,
                multiplier:1,
                constant:0
            ),
            NSLayoutConstraint(
                item:webView,
                attribute:NSLayoutAttribute.width,
                relatedBy:NSLayoutRelation.equal,
                toItem:view,
                attribute:NSLayoutAttribute.width,
                multiplier:1,
                constant:0
            )
        ])
    }
    
    deinit {
        self.endLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.hasLoaded {
            self.reload()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.endLoad()
    }
    
    @IBAction func refresh(_ sender: AnyObject) {
        self.reload()
    }
    
    func reload() {
        let url = URL(string: "https://api.foxelbox.com/map/main/")
        let req = URLRequest(url: url!)
        webView?.load(req)
    }
    
    func beginLoad() {
        if !OSAtomicTestAndSet(0, &self.inNavigation) {
            APIAccessor.incrementRequestsInProgress(1)
        }
    }
    
    func endLoad() {
        if OSAtomicTestAndClear(0, &self.inNavigation) {
            APIAccessor.incrementRequestsInProgress(-1)
        }
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.beginLoad()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.endLoad()
        self.hasLoaded = true
    }
}

