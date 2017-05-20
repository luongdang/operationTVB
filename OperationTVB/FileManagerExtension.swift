//
//  FileManagerExtension.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-19.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation

extension FileManager {
	func moveItem(at sourceURL: URL, to destinationURL: URL, overwriteIfExists: Bool = false) throws {
		let attributes = try self.attributesOfItem(atPath: sourceURL.path)
		let fileType = attributes[FileAttributeKey.type] as! FileAttributeType
		let sourceIsDirectory = ObjCBool(fileType == .typeDirectory)
		
		var destinationIsDirectory = ObjCBool(false)
		if self.fileExists(atPath: destinationURL.path, isDirectory: &destinationIsDirectory)
			&& sourceIsDirectory.boolValue == destinationIsDirectory.boolValue
		{
			let _ = try self.replaceItemAt(destinationURL, withItemAt: sourceURL)
		}
		else {
			try self.moveItem(at: sourceURL, to: destinationURL)
		}
	}
}
