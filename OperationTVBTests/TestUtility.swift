//
//  TestUtility.swift
//  OperationTVBTests
//
//  Created by PowerBook on 2017-10-16.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import XCTest
@testable import OperationTVB

class TestUtility: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

	func testMakeRequest() {
		let urlString = "https://www.apple.com"
		let url = URL(string: urlString)!
		let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.97 Safari/537.36 Vivaldi/1.9.818.49"
		
		let request1 = Utility.makeRequest(with: urlString)
		let headers1 = request1.allHTTPHeaderFields!
		XCTAssert(request1.url?.absoluteString == urlString)
		XCTAssert(headers1["User-Agent"]! == userAgent)
		
		let request2 = Utility.makeRequest(with: url)
		let headers2 = request2.allHTTPHeaderFields!
		XCTAssert(request2.url?.absoluteString == urlString)
		XCTAssert(headers2["User-Agent"]! == userAgent)
	}
}
