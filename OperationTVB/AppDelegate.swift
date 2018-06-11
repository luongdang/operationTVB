//
//  AppDelegate.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-14.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	var webViewWindowController: NSWindowController = {
		return NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "webViewWindowController") as! NSWindowController
	}()

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	@IBAction func showWebViewWindow(_ sender: Any) {
		webViewWindowController.showWindow(self)
	}
}

