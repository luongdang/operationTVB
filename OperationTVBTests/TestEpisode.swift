//
//  TestEpisode.swift
//  OperationTVBTests
//
//  Created by PowerBook on 2018-06-10.
//  Copyright © 2018 LDResearch. All rights reserved.
//

import XCTest
@testable import OperationTVB

class TestEpisode: XCTestCase {
	let windowController: NSWindowController = {
		return NSStoryboard(name: "Main", bundle: nil).instantiateController(withIdentifier: "webViewWindowController") as! NSWindowController
	}()
	
	lazy var webViewController: DebugViewController = {
		return windowController.contentViewController as! DebugViewController
	}()
		
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func test1() {
		let episode = Episode(title: "Flying Tiger - 飛虎之潛行極戰", href: "http://videobug.se/v/A7vSTRTN7-N10xujCV87DQ?download=1", episodeType: .drama)!
		windowController.showWindow(self)
		
		let group = DispatchGroup()
		group.enter()
		webViewController.getVideoURL(for: episode) { (error, url) in
			defer { group.leave() }
			print("Hello world")
		}
		group.wait()
	}
}

