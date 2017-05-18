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
	@IBOutlet weak var downloadingEpisodeLabel: NSTextField!
	@IBOutlet weak var downloadProgressLabel: NSTextField!
	@IBOutlet weak var downloadProgressIndicator: NSProgressIndicator!
	
	@IBOutlet var episodesArrayController: NSArrayController!
	
	
	dynamic var episodes = [Episode]()
	var saveLocation: URL? {
		didSet {
			downloadLocationField.stringValue = saveLocation?.path ?? ""
		}
	}
	var downloadingEpisode: String {
		get {
			return downloadingEpisodeLabel.stringValue
		}
		set {
			DispatchQueue.main.async {
				self.downloadingEpisodeLabel.stringValue = newValue
				
				self.downloadingEpisodeLabel.isHidden = newValue.isEmpty
				self.downloadProgressLabel.isHidden = newValue.isEmpty
				self.downloadProgressIndicator.isHidden = newValue.isEmpty
			}
		}
	}
	
	let formatter : ByteCountFormatter = {
		var formatter = ByteCountFormatter()
		formatter.allowedUnits = [.useMB]
		return formatter
	}()
	
	let semaphore = DispatchSemaphore(value: 3)
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// TODO: remove this line
		self.saveLocation = URL(fileURLWithPath: "/Volumes/Seagate Expansion/Big Data/BitTorrents/OperationTVB")
		downloadingEpisode = ""
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
			self.saveLocation = panel.url
		}
	}
	
	@IBAction func download(_ sender: Any) {
		for episode in self.episodes {
			DispatchQueue.global(qos: .background).async {
				self.semaphore.wait()
				
				print("Next download: \(episode.description)")
				Utility.randomSleep(from: 0, to: 60)
				episode.download(delegate: self)
			}
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
	
	// MARK: - URLSessionDownloadDelegate
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		if let taskDescription = downloadTask.taskDescription {
			downloadingEpisode = taskDescription
		}

		DispatchQueue.main.async {
			let written = self.formatter.string(fromByteCount: totalBytesWritten)
			let expected = self.formatter.string(fromByteCount: totalBytesExpectedToWrite)
			
			self.downloadProgressLabel.stringValue = "\(written) / \(expected)"
			self.downloadProgressIndicator.minValue = 0
			self.downloadProgressIndicator.maxValue = Double(totalBytesExpectedToWrite)
			self.downloadProgressIndicator.doubleValue = Double(totalBytesWritten)
		}
	}
	
	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		downloadingEpisode = ""
		print("\(downloadTask.taskDescription!): finished")
		semaphore.signal()
		
		var filename = downloadTask.response?.suggestedFilename ?? "\(Date()).mp4"
		if let taskDescription = downloadTask.taskDescription,
			let episode = self.episodes.first(where: { $0.description == taskDescription })
		{
			let fileExtension = (filename as NSString).pathExtension
			filename = "\(episode.preferredFilename).\(fileExtension)"
		}
		
		let finalURL = self.saveLocation!.appendingPathComponent(filename)
		let fileManager = FileManager.default
		if fileManager.fileExists(atPath: finalURL.path) {
			try! fileManager.removeItem(at: finalURL)
		}
		try! fileManager.moveItem(at: location, to: finalURL)
	}

}

