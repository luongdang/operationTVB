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

fileprivate var userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.97 Safari/537.36 Vivaldi/1.9.818.49"

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, URLSessionDownloadDelegate {
	@IBOutlet weak var episodeURLField: NSTextField!
	@IBOutlet weak var tableView: NSTableView!
	@IBOutlet weak var downloadLocationField: NSTextField!
	
	@IBOutlet var episodesArrayController: NSArrayController!
	
	dynamic var episodes = [Episode]()
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
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.saveLocation = URL(fileURLWithPath: "/Volumes/Seagate Expansion/Big Data/BitTorrents/OperationTVB")
	}

	@IBAction func loadEpisodes(_ sender: NSButton) {
		let url = URL(string: episodeURLField.stringValue)!
		Episode.downloadEpisodeList(fromURL: url) { episodes in
			DispatchQueue.main.async {
				self.episodes = episodes
			}
		}
	}
	
	@IBAction func browseLocation(_ sender: Any) {
		let panel = NSOpenPanel()
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.beginSheetModal(for: self.view.window!) { button in
			guard button == NSFileHandlingPanelOKButton else {
				return
			}
			self.saveLocation = panel.url!
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
	private let semaphore = DispatchSemaphore(value: 3)
	private let downloadQueue = DispatchQueue(label: "com.ldresearch.operationTVB.episodeDownloadQueue", qos: .background, attributes: [.concurrent])
	
	@IBAction func download(_ sender: Any) {
		for (index, episode) in self.episodes.enumerated() where index < 67 && episode.state != .downloading {
			
			downloadQueue.async {
				self.semaphore.wait()
				
				let waitTime = Utility.randBetween(lowerbound: 0.0, upperbound: 60.0)
				print("Next download: \(episode) in \(waitTime) seconds")
				DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + waitTime) {
					print("\(episode): start processing")
					episode.state = .scheduled
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
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		self.semaphore.signal()
		guard let error = error else { return }
		
		// Handling error
		if let taskDescription = task.taskDescription,
			let episode = self.episodes.first(where: { $0.description == taskDescription })
		{
			episode.state = .failed(error: error.localizedDescription)
		}
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
			episode.state = fileSize.uint64Value < 1_000_000 ? .failed(error: "invalid movie") : .finished
			
			// Create a folder to hold the show
			folderURL.appendPathComponent(episode.title)
			if (episode.language ?? "Cantonese") != "Cantonese" {
				folderURL.appendPathComponent("Extra")
			}
			
			var isDirectory = ObjCBool(false)
			if !(fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory) && isDirectory.boolValue) {
				try! fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false, attributes: [:])
			}
			
			// Set the filename of the episode
			let fileExtension = (fileName as NSString).pathExtension
			fileName = "\(episode.preferredFilename).\(fileExtension)"
		}
		
		let finalURL = folderURL.appendingPathComponent(fileName)
		try! fileManager.moveItem(at: location, to: finalURL, overwriteIfExists: true)
	}
}

