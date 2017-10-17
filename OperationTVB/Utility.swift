//
//  Utilities.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-15.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation
import GameKit

fileprivate let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.97 Safari/537.36 Vivaldi/1.9.818.49"
fileprivate let defaultDateFormatter: DateFormatter = {
	var formatter = DateFormatter()
	formatter.dateStyle = .none
	formatter.timeStyle = .medium
	return formatter
}()

struct Utility {
	static func makeRequest(with urlString: String) -> URLRequest {
		let url = URL(string: urlString)!
		return makeRequest(with: url)
	}
	
	static func makeRequest(with url: URL) -> URLRequest {
		var request = URLRequest(url: url)
		request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
		
		return request
	}
	
	static func randomSleep(from sec1: UInt32, to sec2: UInt32, willEnterSleep: ((UInt32) -> Void)? = nil) {
		let random = arc4random_uniform(sec2 - sec1) + sec1 + 1
		if willEnterSleep == nil {
			print("Sleeping for \(random) seconds")
		} else {
			willEnterSleep!(random)
		}
		sleep(random)
	}
	
	static func randBetween(lowerbound: Int, upperbound: Int) -> Int {
		if lowerbound > upperbound {
			return 0
		} else if lowerbound == upperbound {
			return lowerbound
		} else {
			let rnd = Int(arc4random_uniform(UInt32(upperbound - lowerbound)))
			return rnd + (upperbound - lowerbound) + 1
		}
	}
	
	static func randBetween(lowerbound: Double, upperbound: Double) -> Double {
		if lowerbound > upperbound {
			return 0
		} else if lowerbound == upperbound {
			return lowerbound
		} else {
			let randomRatio = Double(arc4random()) / Double(UInt32.max)
			return lowerbound + (upperbound - lowerbound) * randomRatio
		}
	}
	
	static func timeFromNow(offset seconds: Double, formatter: DateFormatter = defaultDateFormatter) -> String {
		return formatter.string(from: Date().addingTimeInterval(seconds))
	}
	
	static func string(_ str: String, matchRegex regexPattern: String, options: NSRegularExpression.Options = []) -> Bool {
		let regex = try! NSRegularExpression(pattern: regexPattern, options: options)
		return regex.firstMatch(in: str, options: [], range: NSMakeRange(0, str.utf16.count)) != nil
	}
	
	static func substring(for match: NSTextCheckingResult, at index: Int, in text: String) -> String {
		let range = Range(match.range(at: index), in: text)!
		return String(text[range])
	}
}
