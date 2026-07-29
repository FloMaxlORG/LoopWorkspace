//
//  LoopLiveData.swift
//  Loop
//
//  Created by Florian Maxl on 29.07.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//
//  (Optional) Helper code for managing characteristics if the project grows.
//

import Foundation

struct LoopLiveData {

    var glucose: UInt16

    var trend: UInt8

    var delta: Int8

    /// Stored as tenths of a unit.
    /// Example: 15 = 1.5 U
    var iob: Int16

    var cob: UInt16

    var predictedGlucose: UInt16

    var loopClosed: Bool

    var timestamp: Date

}
