//
//  ViewController.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-14.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Cocoa

fileprivate struct Constants {
    /// Wait time before starting to download an episode
    static let waitTime = 0.0 ..< 60.0
    
    /// The maximum number of concurrent downloads
    static let concurrentDownloads = 10
	
	/// Default download location
	static let defaultDownloadURL = URL(fileURLWithPath: "/Volumes/video/(BitTorrent)/OperationTVB")
	
	/// Locations where the app will check for downloaded content
	static let baseURLs = [
		defaultDownloadURL,
		URL(fileURLWithPath: "/Volumes/video/TVB Drama"),
		URL(fileURLWithPath: "/Volumes/video/TV Show - Hong Kong"),
		URL(fileURLWithPath: "/Volumes/Seagate Expansion/Big Data/TVB Drama")
	]
}

@objcMembers
class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, URLSessionDownloadDelegate {
	@IBOutlet weak var episodeURLField: NSTextField!
	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var downloadLocationField: NSTextField!
	@IBOutlet weak var episodesArrayController: NSArrayController!
	
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
		self.saveLocation = Constants.defaultDownloadURL
	}
	
	@IBAction func addEpisodes(_ sender: NSButton) {
		// Verify that the URL is valid
		let stringValue = episodeURLField.stringValue.trimmingCharacters(in: .whitespaces)
		guard let url = URL(string: stringValue) else {
			let alert = NSAlert()
			alert.messageText = "Invalid URL"
			alert.informativeText = stringValue
			alert.alertStyle = .warning
			alert.addButton(withTitle: "OK")
			alert.beginSheetModal(for: view.window!, completionHandler: nil)
			return
		}
		
		let progressIndicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 300, height: 16))
		progressIndicator.isIndeterminate = true
		progressIndicator.startAnimation(nil)
		
		let alert = NSAlert()
		alert.messageText = "Downloading episode list"
		alert.informativeText = " "
		alert.alertStyle = .informational
		alert.accessoryView = progressIndicator
		alert.addButton(withTitle: "Cancel")
		alert.beginSheetModal(for: self.view.window!, completionHandler: nil)
		
		let progressHandler = { (episode: Episode) in
			DispatchQueue.main.async {
				alert.informativeText = episode.title
			}
		}
		
		let completionHandler = { (episodes: [Episode]) in
			DispatchQueue.main.async {
				self.episodes.append(contentsOf: episodes.sorted())
				self.updateState(self)
				self.view.window?.endSheet(alert.window)
			}
		}
		
		if Utility.string(url.lastPathComponent, matchRegex: "page-(\\d+).html") {
			Episode.downloadEpisodeList(fromIndexPage: url, progressHandler: progressHandler, completionHandler: completionHandler)
		} else {
			Episode.downloadEpisodeList(from: url, progressHandler: progressHandler, completionHandler: completionHandler)
		}
	}
	
	@IBAction func revealDownloadLocation(_ sender: NSButton) {
		NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadLocationField.stringValue)
	}
	
	@IBAction func cleanUp(_ sender: Any) {
		self.episodes = episodes.filter { $0.state != .finished }
	}
	
	@IBAction func updateState(_ sender : Any) {
		func episodeExist(_ episode: Episode, at baseURL: URL) -> Bool {
			var expectedURL = baseURL.appendingPathComponent(episode.preferredTitle)
			
			if let subfolder = episode.preferredSubfolder {
				expectedURL.appendPathComponent(subfolder)
			}
			expectedURL.appendPathComponent("\(episode.preferredFilename).mp4")
			
			var isDirectory = ObjCBool(false)
			return FileManager.default.fileExists(atPath: expectedURL.path, isDirectory: &isDirectory) && !isDirectory.boolValue
		}
		
		for episode in self.episodes where episode.state == .notDownloaded {
			let baseURLs = [self.saveLocation!] + Constants.baseURLs
			
			episode.state = baseURLs.reduce(EpisodeDownloadState.notDownloaded) {
				if $0 == .finished {
					return .finished
				} else if episodeExist(episode, at: $1) {
					return .finished
				} else {
					return .notDownloaded
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
			episode.state = .scheduled(at: nil)
			downloadQueue.async {
				self.semaphore.wait()
				let waitTime = Utility.randBetween(range: Constants.waitTime)
				
				episode.state = .scheduled(at: Utility.timeFromNow(offset: waitTime))
				DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + waitTime) {
					print("\(episode): start processing")
					episode.download(delegate: self)
				}
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
		let fileManager = FileManager.default
		var folderURL = self.saveLocation!
		var fileName = downloadTask.response?.suggestedFilename ?? "\(Date()).mp4"
		
		if let taskDescription = downloadTask.taskDescription,
			let episode = self.episodes.first(where: { $0.description == taskDescription })
		{
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
		print("\(task.taskDescription!): finished")
		self.semaphore.signal()
		self.statisticsDidChange()
		
		// Handling error
		if let error = error,
			let taskDescription = task.taskDescription,
			let episode = self.episodes.first(where: { $0.description == taskDescription })
		{
			episode.state = .failed(error: error.localizedDescription)
		}
	}
}

