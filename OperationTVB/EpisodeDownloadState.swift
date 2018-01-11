//
//  EpisodeDownloadState.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-12-25.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation

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
