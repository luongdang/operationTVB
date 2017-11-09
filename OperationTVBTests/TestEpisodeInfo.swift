//
//  TestEpisodeInfo.swift
//  OperationTVBTests
//
//  Created by PowerBook on 2017-10-16.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import XCTest
@testable import OperationTVB

class TestEpisodeInfo: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

	func testParseDrama() {
		if let info = EpisodeInfo(title: "Download Oh My Grad - Episode 05 (Cantonese)", type: .drama) {
			XCTAssert(info.englishTitle == "Oh My Grad")
			XCTAssert(info.episode == "05")
			XCTAssert(info.language == "Cantonese")
		} else {
			XCTFail("info must not be null")
		}
		
		if let info = EpisodeInfo(title: "Download Oh My Grad - Episode 05 (English Subtitles)", type: .drama) {
			XCTAssert(info.englishTitle == "Oh My Grad")
			XCTAssert(info.episode == "05")
			XCTAssert(info.language == "English Subtitles")
		} else {
			XCTFail("info must not be null")
		}
		
		// An invalid title
		XCTAssertNil(EpisodeInfo(title: "Download Smooth Talker Part e - Episode e (e)", type: .drama))
	}
	
	func testParseTVShow() {
		if let info = EpisodeInfo(title: "Download Sunday Report - 2017-10-15 (Cantonese)", type: .tvShow) {
			XCTAssert(info.englishTitle == "Sunday Report")
			XCTAssert(info.episode == "2017-10-15")
			XCTAssert(info.language == "Cantonese")
		} else {
			XCTFail("info must not be null")
		}
		
		if let info = EpisodeInfo(title: "Download J.S.G Music - 2017-10-15 (Cantonese)", type: .tvShow) {
			XCTAssert(info.englishTitle == "J.S.G Music")
			XCTAssert(info.episode == "2017-10-15")
			XCTAssert(info.language == "Cantonese")
		} else {
			XCTFail("info must not be null")
		}
		
		if let info = EpisodeInfo(title: "Download Girls’ Talk - Monday - Episode 29 (Cantonese)", type: .tvShow) {
			XCTAssert(info.englishTitle == "Girls’ Talk - Monday")
			XCTAssert(info.episode == "29")
			XCTAssert(info.language == "Cantonese")
		} else {
			XCTFail("info must not be null")
		}
		
		if let info = EpisodeInfo(title: "Download Sunday Report - 2017-10-15 (Cantonese)", type: .tvShow) {
			XCTAssert(info.englishTitle == "Sunday Report")
			XCTAssert(info.episode == "2017-10-15")
			XCTAssert(info.language == "Cantonese")
		} else {
			XCTFail("info must not be null")
		}
		
		if let info = EpisodeInfo(title: "Download Cantopop At 50 Part 1 - Special (Cantonese)", type: .tvShow) {
			XCTAssert(info.englishTitle == "Cantopop At 50 Part 1")
			XCTAssert(info.episode == "Special")
			XCTAssert(info.language == "Cantonese")
		} else {
			XCTFail("info must not be null")
		}
	}

}
