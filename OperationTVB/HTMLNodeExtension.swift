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
	func firstNode(matchingSelector selectorString: String, withContent textContent: String) -> HTMLElement? {
		return self.nodes(matchingSelector: selectorString).filter({ $0.textContent == textContent }).first
	}
}
