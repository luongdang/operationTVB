//
//  ProgressCellView.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-16.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Cocoa

class ProgressCellView: NSTableCellView {
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
}
