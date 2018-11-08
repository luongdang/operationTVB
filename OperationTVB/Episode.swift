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
	/// The User Agent string used to connect to the website
	static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.97 Safari/537.36 Vivaldi/1.9.818.49"
	
	/// The domain for all errors originated from the Episode class
	static let errorDomain = "com.ldresearch.operationTVB"

	/// The semaphore to control access to webView
	static let webViewSemaphore = DispatchSemaphore(value: 1)
	
	/// The web view in which the site is loaded
	static let webView: WKWebView = {
		var webView: WKWebView!
		DispatchQueue.main.sync {
			webView = WKWebView(frame: .zero)
			webView.customUserAgent = Constants.userAgent
		}
		
		return webView
	}()
	
	/// The formatter used to convert episode into date
	static let episodeDateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US")
		formatter.dateFormat = "yyyy-MM-dd"
		return formatter
	}()
}


@objcMembers class Episode : NSObject {
	var type: EpisodeType
	var title: String
	var chineseTitle: String?
	var language: String?
	var episode: String
	var episodeNumber: Int? {
		return Int(self.episode)
	}
	var episodeAirDate: Date? {
		return Constants.episodeDateFormatter.date(from: episode)
	}
	var url: URL
	
	override var description: String {
		return self.preferredFilename
	}
	
	/// A string describing the epside type for Cocoa Binding
	var episodeType: String {
		return self.type.description
	}
	
	private var downloadDelegate: URLSessionDownloadDelegate!
	
	// MARK: -
	init?(title: String, href: String, episodeType: EpisodeType) {
		guard let info = EpisodeInfo(title: title, type: episodeType) else {
			return nil
		}
		
		self.type         = info.episodeType
		self.title        = info.englishTitle
		self.chineseTitle = info.originalTitle
		self.language     = info.language
		self.episode      = info.episode
		self.url          = URL(string: href)!
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
		
		let episode: String
		if let episodeNumber = self.episodeNumber {
			episode = String(format: "E%02d", episodeNumber)
		} else {
			episode = self.episode
		}
		
		if language == "Cantonese" {
			return "\(title) - \(episode)"
		} else {
			// return String(format: "%@ (%@) - E%02d", title, language, self.episode)
			return "\(title) (\(language)) - \(episode)"
		}
	}

	
	// MARK: - Get the list of episodes
	
	/// Retrieve the list of episode some from the Download page of a show
	///
	/// - Parameters:
	///   - url: The URL of the download page
	///   - progressHandler: The function to call when a new episode has been detected
	///   - completionHandler: The function to call when the list of all episodes has been retrieved
	class func downloadEpisodeList(from url: URL, progressHandler: @escaping ((Episode) -> Void?), completionHandler: @escaping ([Episode]) -> Void) {
		var downloadURL = url
		if downloadURL.lastPathComponent != "download" {
			downloadURL.appendPathComponent("download")
		}
		let request = Utility.makeRequest(with: downloadURL)
		
		let pathComponents = url.pathComponents
		let episodeType: EpisodeType = pathComponents.contains("hk-show") ? .tvShow : .drama
		
		URLSession.shared.dataTask(with: request) { data, response, error in
			guard error == nil else {
				// FIXME: do something about this
				fatalError(error!.localizedDescription)
			}
			
			let document = HTMLDocument(data: data!, contentTypeHeader: nil)
			var result = [Episode]()
			
			for node in document.nodes(matchingSelector: "a[title^=\"Download\"]") {
				let title = node.textContent
				let href = node.attributes["href"]!
				
				if let episode = Episode(title: title, href: href, episodeType: episodeType) {
					result.append(episode)
					progressHandler(episode)
				} else {
					// FIXME: do something about this
					print("Unparsable title: \(title)")
				}
			}
			completionHandler(result)
		}.resume()
	}

	/// Retrieve the list of episode from an index page. An index page can contain multiple shows.
	///
	/// - Parameters:
	///   - url: The URL of the index page
	///   - progressHandler: The function to call when a new episode has been detected
	///   - completionHandler: The function to call when the list of all episodes has been retrieved
	class func downloadEpisodeList(fromIndexPage url: URL, progressHandler: @escaping ((Episode) -> Void?), completionHandler: @escaping ([Episode]) -> Void) {
		let queue = DispatchQueue(label: "com.ldresearch.operationTVB.downloadEpisodeList.fromIndexPageURL", qos: .background, attributes: [])
		let request = Utility.makeRequest(with: url)
		
		URLSession.shared.dataTask(with: request) { data, response, error in
			guard error == nil else {
				// FIXME: do something about this
				print(error!.localizedDescription)
				return
			}
			
			let document = HTMLDocument(data: data!, contentTypeHeader: nil)
			queue.async {
				let group = DispatchGroup()
				var allEpisodes = [Episode]()
				
				for node in document.nodes(matchingSelector: "a.movie-image") {
					let href = node.attributes["href"]!
					guard let url = URL(string: href) else {
						print("Invalid href: '\(href)'")
						continue
					}
					
					group.enter()
					self.downloadEpisodeList(from: url, progressHandler: progressHandler) { episodes in
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
		self.downloadDelegate = delegate
		self.state = .starting
		loadPage1(in: Constants.webView)
	}
	
	/// Open the episode's download page, which contains a list of download providers. The function
	/// then selects the generated link to the Openload service.
	///
	/// The link to Openload on this page does not go directly to Openload. It needs to go through
	/// a few redirects, which is handled in `loadPage2`.
	private func loadPage1(in webView: WKWebView) {
		let request = Utility.makeRequest(with: url)
		
		Constants.webViewSemaphore.wait()
		DispatchQueue.main.async {
			webView.load(request)
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
				webView.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
					defer { Constants.webViewSemaphore.signal() }
					
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
					guard let openloadAnchor = document.firstNode(matchingSelector: "a", withContent: "Openload") else {
						let error = NSError(domain: Constants.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "No Openload link"])
						self.forward(error: error, whileLoadingURL: self.url)
						return
					}
					guard let href = openloadAnchor.attributes["href"], let openloadURL = URL(string: href) else {
						let error = self.makeError(message: "Invalid Openload URL")
						self.forward(error: error, whileLoadingURL: URL(string: "http://invalid")!)
						return
					}
					
					DispatchQueue.global().async {
						self.loadPage2(in: webView, url: openloadURL)
					}
				}
			}
		}
	}
	
	/// Open the URL that redirects to the video viewer page on Openload
	private func loadPage2(in webView: WKWebView, url: URL) {
		let request = Utility.makeRequest(with: url)
		
		Constants.webViewSemaphore.wait()
		DispatchQueue.main.async {
			webView.load(request)
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
				defer { Constants.webViewSemaphore.signal() }
				
				guard let openloadURL = webView.url, let components = URLComponents(url: openloadURL, resolvingAgainstBaseURL: true),
					components.host == "openload.co" else
				{
					let error = self.makeError(message: "Did not redirect to Openload")
					self.forward(error: error, whileLoadingURL: url)
					return
				}
				
				DispatchQueue.global().async {
					self.loadPage3(in: webView, url: openloadURL)
				}
			}
		}
	}
	
	
	/// Get the actual link to the Openload video usign the 9xbuddy website
	private func loadPage3(in webView: WKWebView, url: URL) {
		guard var components = URLComponents(string: "https://9xbuddy.com/process") else {
			let error = self.makeError(message: "Cannot construct 9xbuddy link")
			self.forward(error: error, whileLoadingURL: url)
			return
		}
		
		components.queryItems = [
			URLQueryItem(name: "url", value: url.absoluteString)
		]
		
		let request = Utility.makeRequest(with: components.url!)
		Constants.webViewSemaphore.wait()
		DispatchQueue.main.async {
			webView.load(request)
			
			DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
				webView.evaluateJavaScript("document.documentElement.outerHTML") { html, error in
					defer { Constants.webViewSemaphore.signal() }
					
					guard error == nil else {
						self.forward(error: error, whileLoadingURL: self.url)
						return
					}
					guard let html = html as? String else {
						let error = NSError(domain: Constants.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot extract HTML string"])
						self.forward(error: error, whileLoadingURL: self.url)
						return
					}
					
					let document = HTMLDocument(string: html)
					guard let anchor = document.firstNode(matchingSelector: "a", containingContent: "Download Now"),
						let href = anchor.attributes["href"],
						let videoURL = URL(string: href) else
					{
						let error = self.makeError(message: "Cannot get link to Openload video")
						self.forward(error: error, whileLoadingURL: url)
						return
					}

					DispatchQueue.global().async {
						print(videoURL)
						self.downloadVideo(url: videoURL)
					}
				}
			}
		}
	}
	
	private func downloadVideo(url: URL) {
		let session = URLSession(configuration: .default, delegate: self.downloadDelegate, delegateQueue: nil)
		let request = Utility.makeRequest(with: url)
		
		let task = session.downloadTask(with: request)
		task.taskDescription = self.description
		task.resume()
		
		self.state = .downloading
	}
	
	private func makeError(message: String) -> NSError {
		return NSError(domain: Constants.errorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: message])
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
			return "Starting..."
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
		case .starting:
			return NSColor(deviceRed: 0.086, green: 0.602, blue: 0.042, alpha: 1)
		default:
			return NSColor.black
		}
	}
}

extension Episode: Comparable {
	static func <(lhs: Episode, rhs: Episode) -> Bool {
		if lhs.title != rhs.title {
			return lhs.title < rhs.title
		}
		else if lhs.language != rhs.language {
			return (lhs.language ?? "" ) < (rhs.language ?? "")
		}
		else if let lhsEpisode = lhs.episodeNumber,
			let rhsEpisode = rhs.episodeNumber,
			lhsEpisode != rhsEpisode
		{
			return lhsEpisode < rhsEpisode
		}
		else if let lhsEpisode = lhs.episodeAirDate,
			let rhsEpisode = rhs.episodeAirDate,
			lhsEpisode != rhsEpisode
		{
			return lhsEpisode < rhsEpisode
		}
		else if lhs.episode != rhs.episode {
			return lhs.episode < rhs.episode
		} else {
			return true
		}
	}
}
