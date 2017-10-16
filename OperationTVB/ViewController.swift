//
//  ViewController.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-14.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Cocoa
import WebKit
import HTMLReader

fileprivate struct Constants {
    /// Wait time before starting to download an episode
    static let waitTime = 0.0 ..< 60.0
    
    /// The number of concurrent downloads
    static let concurrentDownloads = 20
}

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, URLSessionDownloadDelegate {
	@IBOutlet weak var episodeURLField: NSTextField!
	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var downloadLocationField: NSTextField!
	
	@IBOutlet var episodesArrayController: NSArrayController!
	
	@objc dynamic var episodes = [Episode]() {
		didSet {
			self.statisticsDidChange()
		}
	}
	@objc dynamic var statistics : String {
		let finishedCount = episodes.filter({ $0.state == .finished }).count
		let totalCount = episodes.count
		let showCount = Set(episodes.map({ $0.title })).count
		let failedCount = episodes.filter({ $0.state == .failed(error: "") }).count
		
		var statisticString = "\(showCount) shows. \(totalCount) episodes."
		if finishedCount > 0 {
			statisticString += " \(finishedCount) finished."
		}
		if failedCount > 0 {
			statisticString += " \(failedCount) failed."
		}
		
		return statisticString
	}
	
	var saveLocation: URL? {
		didSet {
			downloadLocationField.stringValue = saveLocation?.path ?? ""
		}
	}
	
	let formatter : ByteCountFormatter = {
		var formatter = ByteCountFormatter()
		formatter.allowedUnits = [.useMB]
		return formatter
	}()
	
	// MARK: - Methods
	override func viewDidLoad() {
		super.viewDidLoad()
		self.saveLocation = URL(fileURLWithPath: "/Volumes/Macintosh HD/TVB")
	}
	
	@IBAction func addEpisodes(_ sender: NSButton) {
		let url = URL(string: episodeURLField.stringValue)!
		let completionHandler = { (episodes: [Episode]) in
			DispatchQueue.main.async {
				let sortedEpisodes = episodes.sorted {
					if $0.title != $1.title {
						return $0.title < $1.title
					} else if let language0 = $0.language, let language1 = $1.language, language0 != language1 {
						return language0 < language1
					} else if $0.episodeNumber != $1.episodeNumber {
						return $0.episodeNumber < $1.episodeNumber
					} else {
						return false
					}
				}
				
				self.episodes.append(contentsOf: sortedEpisodes)
				self.updateState(self)
			}
		}
		
		if Utility.string(url.lastPathComponent, matchRegex: "page-(\\d+).html") {
			Episode.downloadEpisodeList(fromIndexPageURL: url, completionHandler: completionHandler)
		} else {
			Episode.downloadEpisodeList(fromURL: url, completionHandler: completionHandler)
		}
	}
	
	@IBAction func cleanUp(_ sender: Any) {
		self.episodes = episodes.filter { $0.state != .finished }
	}
	
	@IBAction func updateState(_ sender : Any) {
		func checkEpisode(_ episode: Episode, existsAtBaseURL baseURL: URL) -> Bool {
			var expectedURL = baseURL.appendingPathComponent(episode.preferredTitle)
			
			if let subfolder = episode.preferredSubfolder {
				expectedURL.appendPathComponent(subfolder)
			}
			expectedURL.appendPathComponent("\(episode.preferredFilename).mp4")
			
			var isDirectory = ObjCBool(false)
			return FileManager.default.fileExists(atPath: expectedURL.path, isDirectory: &isDirectory) && !isDirectory.boolValue
		}
		
		for episode in self.episodes {
			let baseURLs = [
				self.saveLocation!,
				URL(fileURLWithPath: "/Volumes/Seagate Expansion/Big Data/TVB Drama"),
				URL(fileURLWithPath: "/Volumes/Macintosh HD/TVB"),
				URL(fileURLWithPath: "/Volumes/video/TVB Drama")
			]
			
			episode.state = baseURLs.reduce(EpisodeDownloadState.notDownloaded) {
				if $0 == .finished {
					return .finished
				} else {
					return checkEpisode(episode, existsAtBaseURL: $1) ? .finished : .notDownloaded
				}
			}
		}
	}
	
	
	@IBAction func browseLocation(_ sender: Any) {
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		
		panel.beginSheetModal(for: self.view.window!) { button in
			guard button.rawValue == NSFileHandlingPanelOKButton else {
				return
			}
			self.saveLocation = panel.url!
		}
	}
	
	func statisticsDidChange() {
		DispatchQueue.main.async {
			self.willChangeValue(forKey: "statistics")
			self.didChangeValue(forKey: "statistics")
		}
	}
	
	
	// MARK: - Keyboard Events
	override func keyDown(with event: NSEvent) {
		interpretKeyEvents([event])
	}
	
	override func deleteForward(_ sender: Any?) {
		deleteSelectedRows()
	}
	
	override func deleteBackward(_ sender: Any?) {
		deleteSelectedRows()
	}
	
	private func deleteSelectedRows() {
		if let selectedRows = episodesArrayController.selectedObjects {
			episodesArrayController.remove(contentsOf: selectedRows)
		}
	}
	
	
	// MARK: - Download & URLSessionDownloadDelegate
	private let semaphore = DispatchSemaphore(value: Constants.concurrentDownloads)
	private let downloadQueue = DispatchQueue(label: "com.ldresearch.operationTVB.episodeDownloadQueue", qos: .background, attributes: [])
	
	@IBAction func download(_ sender: Any) {
		for episode in self.episodes where episode.state == .notDownloaded || episode.state.hasFailed {
			download(episode: episode, waitTime: Constants.waitTime)
		}
	}
	
	private func download(episode: Episode, waitTime: Range<Double>) {
		episode.state = .scheduled(at: nil)
		downloadQueue.async {
			self.semaphore.wait()
			let waitTime = Utility.randBetween(lowerbound: waitTime.lowerBound, upperbound: waitTime.upperBound)
			
			episode.state = .scheduled(at: Utility.timeFromNow(offset: waitTime))
			DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + waitTime) {
				print("\(episode): start processing")
				episode.download(delegate: self)
			}
		}
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		if let taskDescription = downloadTask.taskDescription,
			let episode = self.episodes.first(where: { $0.description == taskDescription }),
			(totalBytesWritten - episode.totalBytesWritten) > Int64(1 << 20)
		{
			episode.state = .downloading
			episode.totalBytesWritten = totalBytesWritten
			episode.totalBytesExpected = totalBytesExpectedToWrite
		}
	}
	
	func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
		print("Session failed: \(error?.localizedDescription ?? "unknown session error")")
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		print("\(downloadTask.taskDescription!): finished")
		
		let fileManager = FileManager.default
		var folderURL = self.saveLocation!
		var fileName = downloadTask.response?.suggestedFilename ?? "\(Date()).mp4"
		
		if let taskDescription = downloadTask.taskDescription,
			let episode = self.episodes.first(where: { $0.description == taskDescription })
		{
			// Fail the episode if the file size is too small
			let fileAttributes = try! fileManager.attributesOfItem(atPath: location.path)
			let fileSize = fileAttributes[FileAttributeKey.size] as! NSNumber
			
			guard fileSize.uint64Value > 1_000_000 else {
				episode.state = .failed(error: "file too small")
				DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 300) { // try again after 5 minutes
					self.download(episode: episode, waitTime: 0..<60)
				}
				return
			}
			episode.state = .finished
			
			// Create a folder to hold the show
			folderURL.appendPathComponent(episode.title)
			if let subfolder = episode.preferredSubfolder {
				folderURL.appendPathComponent(subfolder)
			}
			
			var isDirectory = ObjCBool(false)
			if !(fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) && isDirectory.boolValue) {
				try! fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: [:])
			}
			
			// Set the filename of the episode
			let fileExtension = (fileName as NSString).pathExtension
			fileName = "\(episode.preferredFilename).\(fileExtension)"
		}
		
		let finalURL = folderURL.appendingPathComponent(fileName)
		try! fileManager.moveItem(at: location, to: finalURL, overwriteIfExists: true)
	}
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		self.semaphore.signal()
		self.statisticsDidChange()
		
		// Handling error
		if let error = error,
			let taskDescription = task.taskDescription,
			let episode = self.episodes.first(where: { $0.description == taskDescription })
		{
			episode.state = .failed(error: error.localizedDescription)
			
			// Download again after 5 minutes
			if error.localizedDescription != "No H265 Link" {
				DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 300) {
					self.download(episode: episode, waitTime: 0..<60)
				}
			}
		}
	}
}

