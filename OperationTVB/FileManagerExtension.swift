//
//  FileManagerExtension.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-19.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation

extension FileManager {
	
	/// Move an file / folder to a new location, with option to overwrite file / folder at the
	///	destination if it exists
	///
	/// - Parameters:
	///   - sourceURL: The `URL` to the original item
	///   - destinationURL: The `URL` to the destination
	///   - overwriteIfExists: `true` to overwrite the destination file / folder if it exists
	/// - Throws: An `NSError` if user does not have permission to read the `sourceURL` or write to
	///				`destinationURL`
	func moveItem(at sourceURL: URL, to destinationURL: URL, overwriteIfExists: Bool = false) throws {
		let attributes = try self.attributesOfItem(atPath: sourceURL.path)
		let fileType = attributes[FileAttributeKey.type] as! FileAttributeType
		let sourceIsDirectory = ObjCBool(fileType == .typeDirectory)
		
		var destinationIsDirectory = ObjCBool(false)
		if self.fileExists(atPath: destinationURL.path, isDirectory: &destinationIsDirectory)
			&& sourceIsDirectory.boolValue == destinationIsDirectory.boolValue
		{
			// let _ = try self.replaceItemAt(destinationURL, withItemAt: sourceURL)
			try self.removeItem(at: destinationURL)
		}
		
		try self.moveItem(at: sourceURL, to: destinationURL)
	}
}
