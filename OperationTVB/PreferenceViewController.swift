//
//  PreferenceViewController.swift
//  OperationTVB
//
//  Created by PowerBook on 2018-04-27.
//  Copyright © 2018 LDResearch. All rights reserved.
//

import Cocoa

class PreferenceViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Preferences.reigsterDefaults()
    }
    
}
