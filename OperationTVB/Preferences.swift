//
//  Preferences.swift
//  OperationTVB
//
//  Created by PowerBook on 2018-04-27.
//  Copyright © 2018 LDResearch. All rights reserved.
//

import Foundation

struct Preferences {
	static func reigsterDefaults() {
		UserDefaults.standard.register(defaults: [
			kConcurrentDownloads: 20,
			kDefaultDownloadURL: URL(fileURLWithPath: "/Volumes/video/(BitTorrent)/OperationTVB")
		])
	}
	
	private static let kConcurrentDownloads = "concurrentDownloads"
	static var concurrenDownloads: Int {
		get { return UserDefaults.standard.integer(forKey: kConcurrentDownloads) }
		set { UserDefaults.setValue(newValue, forKey: kConcurrentDownloads) }
	}
	
	private static let kDefaultDownloadURL = "defaultDownloadURL"
	static var defaultDownloadURL: URL {
		get { return UserDefaults.standard.url(forKey: kDefaultDownloadURL)! }
		set { UserDefaults.standard.setValue(newValue, forKeyPath: kDefaultDownloadURL) }
	}
}
