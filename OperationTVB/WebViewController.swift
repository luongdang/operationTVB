//
//  WebViewController.swift
//  OperationTVB
//
//  Created by PowerBook on 2018-06-10.
//  Copyright © 2018 LDResearch. All rights reserved.
//

import Cocoa
import WebKit

class WebViewController: NSViewController {
	@IBOutlet weak var urlField: NSTextField!
	@IBOutlet weak var webView: WKWebView!
	
	private var completionHandler: ((Error?, URL?) -> Void)? = nil
	private var navigation1: WKNavigation? = nil
	
	override func viewDidLoad() {
		super.viewDidLoad()
		webView.uiDelegate = self
		webView.navigationDelegate = self
	}
	
	func getVideoURL(for episode: Episode, completionHandler: @escaping (Error?, URL?) -> Void) {
		self.completionHandler = completionHandler
		self.navigation1 = load(episode.url)
	}
	
	private func load(_ url: URL) -> WKNavigation? {
		let request = URLRequest(url: url)
		return webView.load(request)
	}
}

extension WebViewController: WKUIDelegate, WKNavigationDelegate {
	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		guard let urlString = webView.url?.absoluteString else { return }
		urlField.stringValue = urlString
	}
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		guard let urlString = webView.url?.absoluteString else { return }
		urlField.stringValue = urlString
		
		if navigation.isEqual(navigation1) {
			self.completionHandler?(nil, nil)
		}
	}
}
