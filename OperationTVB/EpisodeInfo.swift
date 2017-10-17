//
//  EpisodeType.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-10-16.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation

enum EpisodeType {
	case drama
	case tvShow
}


struct EpisodeInfo {
	var episodeType: EpisodeType
	var englishTitle: String
	var originalTitle: String?
	var episode: String
	var language: String
	
	init?(title: String, type: EpisodeType) {
		let fullRange = NSRange(title.startIndex..<title.endIndex, in: title)
		
		switch type {
		case .drama:
			if let pattern = try? NSRegularExpression(pattern: "Download (.+) - Episode (\\d+) \\((.+)\\)", options: []),
				let match = pattern.firstMatch(in: title, options: [], range: fullRange)
			{
				self.episodeType  = .drama
				self.englishTitle = Utility.substring(for: match, at: 1, in: title)
				self.episode      = Utility.substring(for: match, at: 2, in: title)
				self.language     = Utility.substring(for: match, at: 3, in: title)
			}
			else if let pattern = try? NSRegularExpression(pattern: "Download (.+) - (.+) - Episode (\\d+) \\((.+)\\)", options: []),
				let match = pattern.firstMatch(in: title, options: [], range: fullRange)
			{
				self.episodeType   = .drama
				self.englishTitle  = Utility.substring(for: match, at: 1, in: title)
				self.originalTitle = Utility.substring(for: match, at: 2, in: title)
				self.episode       = Utility.substring(for: match, at: 3, in: title)
				self.language      = Utility.substring(for: match, at: 4, in: title)
			}
			else {
				return nil
			}
			
		case .tvShow:
			if let pattern = try? NSRegularExpression(pattern: "Download (.+) - Episode (.+) \\((.+)\\)", options: []),
				let match = pattern.firstMatch(in: title, options: [], range: fullRange)
			{
				self.episodeType  = .drama
				self.englishTitle = Utility.substring(for: match, at: 1, in: title)
				self.episode      = Utility.substring(for: match, at: 2, in: title)
				self.language     = Utility.substring(for: match, at: 3, in: title)
			}
			else if let pattern = try? NSRegularExpression(pattern: "Download (.+) - (.+) \\((.+)\\)", options: []),
				let match = pattern.firstMatch(in: title, options: [], range: fullRange)
			{
				self.episodeType  = .drama
				self.englishTitle = Utility.substring(for: match, at: 1, in: title)
				self.episode      = Utility.substring(for: match, at: 2, in: title)
				self.language     = Utility.substring(for: match, at: 3, in: title)
			}
			else {
				return nil
			}
		}
	}
}
