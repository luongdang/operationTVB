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

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
	
	func test1() {
		let episode = Episode(title: "Flying Tiger - 飛虎之潛行極戰", href: "http://videobug.se/v/A7vSTRTN7-N10xujCV87DQ?download=1", episodeType: .drama)!
		episode.download(delegate: self)
	}

	func test2() {
		let url = URL(string: "http://videobug.se/v/A7vSTRTN7-N10xujCV87DQ?download=1")!
		let group = DispatchGroup()
		
		group.enter()
		URLSession.shared.dataTask(with: url) { data, response, error in
			defer { group.leave() }
			guard error == nil else {
				XCTFail(error!.localizedDescription)
				return
			}
			guard let data = data else {
				XCTFail("Data is empty")
				return
			}
			
			let outputURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!.appendingPathComponent("data.html")
			try! data.write(to: outputURL, options: .atomic)
		}.resume()
		group.wait()
	}
}

extension TestEpisode: URLSessionDownloadDelegate {
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		print(location)
	}
}
