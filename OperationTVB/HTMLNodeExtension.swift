//
//  HTMLNodeExtension.swift
//  OperationTVB
//
//  Created by PowerBook on 2017-05-16.
//  Copyright © 2017 LDResearch. All rights reserved.
//

import Foundation
import HTMLReader

extension HTMLNode {
	func firstNode(matchingSelector selector: String, withContent textContent: String) -> HTMLElement? {
		return self.nodes(matchingSelector: selector).first { $0.textContent == textContent }
	}
	
	func firstNode(matchingSelector selector: String, containingContent textContent: String) -> HTMLElement? {
		return self.nodes(matchingSelector: selector).first { $0.textContent.contains(textContent) }
	}
}
