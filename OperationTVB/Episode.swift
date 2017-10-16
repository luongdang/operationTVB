//
//  EpisodeParser.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-14.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation
import HTMLReader
import WebKit

fileprivate struct Constants {
	static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.97 Safari/537.36 Vivaldi/1.9.818.49"
	static let errorDomain = "com.ldresearch.operationTVB"

	static let webViewSemaphore = DispatchSemaphore(value: 1)
	static let webView: WKWebView = {
		var webView: WKWebView!
		DispatchQueue.main.sync {
			webView = WKWebView(frame: .zero)
			webView.customUserAgent = Constants.userAgent
		}
		return webView
	}()
}

enum EpisodeDownloadState : Equatable {
	case notDownloaded
	case scheduled(at: String?)
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
	
	var hasFailed: Bool {
		switch self {
		case .failed(error: _):
			return true
		default:
			return false
		}
	}
}

@objcMembers
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
	
	var maxRetries = 100
	private var retries = 0
	private var downloadDelegate: URLSessionDownloadDelegate!
	
	
	init?(title: String, href: String) {
		let regex1 = try! NSRegularExpression(pattern: "Download (.+) - (.+) - Episode (\\d+).*\\((.+)\\)", options: [])
		let regex2 = try! NSRegularExpression(pattern: "Download (.+) - (.+) - Episode (\\d+)", options: [])
		
		/*
		let nsTitle = title as NSString
		let fullRange = NSMakeRange(0, nsTitle.length)
		*/
		let fullRange = NSRange(location: 0, length: title.utf16.count)
		
		guard let match = [regex1, regex2].reduce(nil, { $0 != nil ? $0 : $1.firstMatch(in: title, options: [], range: fullRange) }) else {
			return nil
		}

		let ranges = (0 ..< match.numberOfRanges).map { Range(match.range(at: $0), in: title)! }
		self.title = String(title[ranges[1]])
		self.chineseTitle = String(title[ranges[2]])
		self.episodeNumber = Int(title[ranges[3]])!
		self.url = URL(string: href)!
		
		if ranges.count == 5 {
			self.language = String(title[ranges[4]])
		}
		/*
		self.title = nsTitle.substring(with: match.range(at: 1))
		self.chineseTitle = nsTitle.substring(with: match.range(at: 2))
		self.episodeNumber = Int(nsTitle.substring(with: match.range(at: 3)))!
		self.url = URL(string: href)!

		if match.numberOfRanges == 5 {
			self.language = nsTitle.substring(with: match.range(at: 4))
		}
		*/
	}
	
	// MARK: - Properties for saving files to disk
	var preferredSubfolder : String? {
		switch self.language {
		case nil:
			return nil
		case .some(let lang) where ["Cantonese", "English/Cantonese Subtitles"].contains(lang):
			return nil
		default:
			return "Extra"
		}
	}
	
	var preferredTitle : String {
		return self.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: " -")
	}
	
	var preferredFilename : String {
		let title = self.preferredTitle
		let language = self.language?.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: " -") ?? "Cantonese"
		
		if language == "Cantonese" {
			return String(format: "%@ - E%02d", title, self.episodeNumber)
		} else {
			return String(format: "%@ (%@) - E%02d", title, language, self.episodeNumber)
		}
	}

	
	// MARK: - Get list of episodes
	class func downloadEpisodeList(fromURL url: URL, completionHandler: @escaping ([Episode]) -> Void) {
		var downloadURL = url
		if downloadURL.lastPathComponent != "download" {
			downloadURL.appendPathComponent("download")
		}
		let request = Utility.makeRequest(with: downloadURL)
		
		URLSession.shared.dataTask(with: request) { data, response, error in
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
					print("Unparsable title: \(title)")
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
	
	class func downloadEpisodeList(fromIndexPageURL url: URL, completionHandler: @escaping ([Episode]) -> Void) {
		let queue = DispatchQueue(label: "com.ldresearch.operationTVB.downloadEpisodeList.fromIndexPageURL", qos: .background, attributes: [])
		let request = Utility.makeRequest(with: url)
		
		URLSession.shared.dataTask(with: request) { data, response, error in
			guard error == nil else {
				print(error!.localizedDescription)
				return
			}
			
			let document = HTMLDocument(data: data!, contentTypeHeader: nil)
			
			queue.async {
				let group = DispatchGroup()
				var allEpisodes = [Episode]()
				
				for node in document.nodes(matchingSelector: "a.movie-image") {
					let href = URL(string: node.attributes["href"]!)!
					
					group.enter()
					self.downloadEpisodeList(fromURL: href) { episodes in
						DispatchQueue.main.async {
							allEpisodes.append(contentsOf: episodes)
							group.leave()
						}
					}
				}
				
				group.wait()
				completionHandler(allEpisodes)
			}
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
		loadPage1(in: Constants.webView)
	}
	
	private func loadPage1(in webView: WKWebView) {
		let request = Utility.makeRequest(with: url)
		
		Constants.webViewSemaphore.wait()
		DispatchQueue.main.async {
			webView.load(request)
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
				webView.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
					defer {
						Constants.webViewSemaphore.signal()
					}
					guard error == nil else {
						self.forward(error: error, whileLoadingURL: self.url)
						return
					}
					guard let htmlString = result as? String else {
						let error = NSError(domain: Constants.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot extract HTML string"])
						self.forward(error: error, whileLoadingURL: self.url)
						return
					}
					
					let document = HTMLDocument(string: htmlString)
					let picasaAnchor = document.firstNode(matchingSelector: "a", withContent: "Picasaweb 720p") ??
										document.firstNode(matchingSelector: "a", withContent: "Picasaweb 360p")
					if picasaAnchor == nil {
						let error = NSError(domain: Constants.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "No Picasa link"])
						self.forward(error: error, whileLoadingURL: self.url)
						return
					}
					
					let href = picasaAnchor!.attributes["href"]!
					self.loadPage2(href: href)
				}
			}
		}
	}
	
	private func loadPage2(href: String) {
		let session = URLSession(configuration: .default, delegate: self.downloadDelegate, delegateQueue: nil)
		let request = Utility.makeRequest(with: href)
		
		let task = session.downloadTask(with: request)
		task.taskDescription = self.description
		task.resume()
		
		self.state = .downloading
	}
	
	private func forward(error: Error?, whileLoadingURL url: URL) {
		let task = URLSession.shared.dataTask(with: url)
		task.taskDescription = self.description
		
		self.downloadDelegate.urlSession?(URLSession.shared, task: task, didCompleteWithError: error)
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
		case .scheduled(let atTime):
			if let atTime = atTime {
				return "Scheduled for \(atTime)"
			} else {
				return "Scheduled"
			}
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
		case .scheduled(_):
			return NSColor.lightGray
		default:
			return NSColor.black
		}
	}
}
