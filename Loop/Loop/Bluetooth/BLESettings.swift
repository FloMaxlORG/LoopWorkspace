//
//  BLESettings.swift
//  Loop
//
//  Created by Florian Maxl on 30.07.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

enum BLESettings {
    
    private static let enabledKey = "LoopBLEEnabled"
    
    static var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }
}
