//
//  EpisodeParser.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-14.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation
import HTMLReader

enum EpisodeDownloadState : Equatable {
	case notDownloaded
	case scheduled
	case starting
	case downloading
	case finished
	case failed(error: String)
	
	static func == (lhs: EpisodeDownloadState, rhs: EpisodeDownloadState) -> Bool {
		switch (lhs, rhs) {
		case (.notDownloaded, .notDownloaded), (.scheduled, .scheduled), (.starting, .starting),
		     (.downloading, .downloading), (.finished, finished), (.failed, .failed):
		     return true
		default:
			return false
		}
	}
}

class Episode : NSObject {
	var title: String
	var chineseTitle: String
	var language: String?
	var episodeNumber: Int
	var url: URL
	
	override var description: String {
		if let language = self.language {
			return String(format: "%@ - E%02d (%@)", title, episodeNumber, language)
		} else {
			return String(format: "%@ - E%02d", title, episodeNumber)
		}
	}
	
	var preferredFilename : String {
		let language = self.language ?? "Cantonese"
		if language == "Cantonese" {
			return String(format: "%@ - E%02d", self.title, self.episodeNumber)
		} else {
			return String(format: "%@ (%@) - E%02d", self.title, language, self.episodeNumber)
		}
	}
	
	var maxRetries = 100
	private var retries = 0
	private var downloadDelegate: URLSessionDownloadDelegate!
	
	
	init?(title: String, href: String) {
		let regex1 = try! NSRegularExpression(pattern: "Download (.+) - (.+) - Episode (\\d+).*\\((.+)\\)", options: [])
		let regex2 = try! NSRegularExpression(pattern: "Download (.+) - (.+) - Episode (\\d+)", options: [])
		
		let nsTitle = title as NSString
		let fullRange = NSMakeRange(0, nsTitle.length)
		
		guard let match = [regex1, regex2].reduce(nil, { $0 != nil ? $0 : $1.firstMatch(in: title, options: [], range: fullRange) }) else {
			return nil
		}
		
		self.title = nsTitle.substring(with: match.rangeAt(1))
		self.chineseTitle = nsTitle.substring(with: match.rangeAt(2))
		self.episodeNumber = Int(nsTitle.substring(with: match.rangeAt(3)))!
		self.url = URL(string: href)!
		
		if match.numberOfRanges == 5 {
			self.language = nsTitle.substring(with: match.rangeAt(4))
		}
	}
	
	
	class func downloadEpisodeList(fromURL url: URL, completionHandler: @escaping ([Episode]) -> Void) {
		let request = Utility.makeRequest(with: url)
		
		URLSession.shared.dataTask(with: request) { (data, response, error) in
			guard error == nil else {
				fatalError(error!.localizedDescription)
			}
			
			let document = HTMLDocument(data: data!, contentTypeHeader: nil)
			var result = [Episode]()
			
			for node in document.nodes(matchingSelector: "a[title^=\"Download\"]") {
				let title = node.attributes["title"]!
				let href = node.attributes["href"]!
				if let episode = Episode(title: title, href: href) {
					result.append(episode)
				} else {
					print("un-parsable: \(title)")
				}
			}
			result.sort {
				let language0 = $0.language ?? ""
				let language1 = $1.language ?? ""
				let episodeNumber0 = $0.episodeNumber
				let episodeNumber1 = $1.episodeNumber
				
				if language0 != language1 {
					return language0 < language1
				} else {
					return episodeNumber0 < episodeNumber1
				}
			}
			completionHandler(result)
		}.resume()

	}
	
	
	// MARK: - Download an episode
	func download(delegate: URLSessionDownloadDelegate) {
		download(delegate: delegate, resetRetries: true)
	}
	
	private func download(delegate: URLSessionDownloadDelegate, resetRetries: Bool) {
		self.downloadDelegate = delegate
		if resetRetries {
			self.retries = 0
		}
		self.state = .starting
		loadPage1()
	}
	
	private func loadPage1() {
		let request = Utility.makeRequest(with: self.url)
		URLSession.shared.dataTask(with: request) { data, response, error in
			let document = HTMLDocument(data: data!, contentTypeHeader: nil)
			let h265Anchor = document.firstNode(matchingSelector: "a", withContent: "H265")!
			let href = h265Anchor.attributes["href"]!
			
			self.loadPage2(href: href)
		}.resume()
	}
	
	private func loadPage2(href: String) {
		let request = Utility.makeRequest(with: href)
		URLSession.shared.dataTask(with: request) { data, response, error in
			let document = HTMLDocument(data: data!, contentTypeHeader: nil)
			let highQualityAnchor = document.firstNode(matchingSelector: "a", withContent: "High quality")
			let normalQualityAnchor = document.firstNode(matchingSelector: "a", withContent: "Normal quality")
			
			let downloadAnchor = (highQualityAnchor ?? normalQualityAnchor)!
			let functionText = downloadAnchor.attributes["onclick"]!
			self.loadPage3(functionText: functionText)
		}.resume()
	}
	
	private func loadPage3(functionText: String) {
		let regex = try! NSRegularExpression(pattern: "download_video\\('(.+)','(.)','(.+)'\\)", options: [])
		let nsFunctionText = functionText as NSString
		
		let match = regex.firstMatch(in: functionText, options: [], range: NSMakeRange(0, nsFunctionText.length))!
		let code = nsFunctionText.substring(with: match.rangeAt(1))
		let mode = nsFunctionText.substring(with: match.rangeAt(2))
		let hash = nsFunctionText.substring(with: match.rangeAt(3))
		
		var urlComponents = URLComponents(string: "http://h265.se/dl")!
		urlComponents.queryItems = [
			URLQueryItem(name: "op", value: "download_orig"),
			URLQueryItem(name: "id", value: code),
			URLQueryItem(name: "mode", value: mode),
			URLQueryItem(name: "hash", value: hash)
		]
		
		let cookie = HTTPCookieStorage.shared.cookies!
						.filter { $0.domain == ".h265.se" }
						.map { "\($0.name)=\($0.value)" }
						.joined(separator: "; ")
		
		var request = Utility.makeRequest(with: urlComponents.url!)
		request.setValue(cookie, forHTTPHeaderField: "Cookie")
		
		URLSession.shared.dataTask(with: request) { data, response, error in
			let document = HTMLDocument(data: data!, contentTypeHeader: nil)
			if let downloadAnchor = document.firstNode(matchingSelector: "a", withContent: "Direct Download Link") {
				print("\(self.description): start download")
				let href = downloadAnchor.attributes["href"]!
				self.loadPage4(href: href)
			} else if self.retries < self.maxRetries {
				self.retries += 1
				print("\(self.description): retries \(self.retries)")
				Utility.randomSleep(from: 1, to: 5)
				self.download(delegate: self.downloadDelegate, resetRetries: false)
			} else {
				fatalError("Too many retries")
			}
		}.resume()
	}
	
	private func loadPage4(href: String) {
		let session = URLSession(configuration: .default, delegate: self.downloadDelegate, delegateQueue: nil)
		let request = Utility.makeRequest(with: href)
		
		let task = session.downloadTask(with: request)
		task.taskDescription = self.description
		task.resume()
		
		self.state = .downloading
	}
	
	// MARK: - Download state
	private let downloadProgressFormatter: NumberFormatter = {
		var formatter = NumberFormatter()
		formatter.numberStyle = .percent
		formatter.maximumFractionDigits = 1
		return formatter
	}()
	
	private func stateDidChange() {
		DispatchQueue.main.async {
			self.willChangeValue(forKey: "stateDescription")
			self.didChangeValue(forKey: "stateDescription")
			
			self.willChangeValue(forKey: "stateColor")
			self.didChangeValue(forKey: "stateColor")
		}
	}
	var state = EpisodeDownloadState.notDownloaded {
		didSet { self.stateDidChange() }
	}
	var totalBytesWritten: Int64 = 0 {
		didSet { self.stateDidChange() }
	}
	var totalBytesExpected: Int64 = 0 {
		didSet { self.stateDidChange() }
	}
	
	var stateDescription : String {
		switch self.state {
		case .notDownloaded:
			return ""
		case .scheduled:
			return "Scheduled"
		case .starting:
			return "Starting... \(self.retries + 1)"
		case .downloading:
			let percentage = self.totalBytesExpected > 0 ? Double(self.totalBytesWritten) / Double(self.totalBytesExpected) : 0
			return self.downloadProgressFormatter.string(from: NSNumber(value: percentage))!
		case .finished:
			return "Finished"
		case .failed(let errorMessage):
			return "Failed: \(errorMessage)"
		}
	}
	
	var stateColor : NSColor {
		switch self.state {
		case .finished:
			return NSColor.lightGray
		case .failed:
			return NSColor.red
		default:
			return NSColor.black
		}
	}
}

