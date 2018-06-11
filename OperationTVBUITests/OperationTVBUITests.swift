//
//  OperationTVBUITests.swift
//  OperationTVBUITests
//
//  Created by PowerBook on 2017-05-14.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import XCTest
@testable import OperationTVB

class OperationTVBUITests: XCTestCase {
//	lazy var appDelegate = (NSApp.delegate as! AppDelegate)
//	lazy var webViewWindowController: NSWindowController = self.appDelegate.webViewWindowController
//	lazy var webViewController: WebViewController = self.webViewWindowController.contentViewController as! WebViewController
	
        
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
	func test1() {
		let app = XCUIApplication()
		app.launch()
		
		// Show WebView Debugger window
		app.typeKey("d", modifierFlags: .command)
		let debuggerWindow = app.windows["WebView Debugger"].firstMatch
		XCTAssertTrue(debuggerWindow.exists)
		
		
		// Show main window
		let mainWindow = app.windows["Operation TVB"].firstMatch
		let episodeURLField = mainWindow.textFields["episodeURLField"].firstMatch
		episodeURLField.typeText("http://icdrama.se/hk-drama/3774-flying-tiger/")
		
		mainWindow.buttons["Add"].click()
		sleep(2)
	}
	
}
