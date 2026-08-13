//
//  BLEUUIDs.swift
//  Loop
//
//  Created by Florian Maxl on 29.07.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//
//  Stores all service and characteristic UUIDs in one place.
//

import CoreBluetooth

enum BLEUUIDs {

    static let liveDataService = CBUUID(
        string: "B734F6C1-4713-4E88-A1A6-2E285FC90A01"
    )

    static let liveData = CBUUID(
        string: "B734F6C1-4713-4E88-A1A6-2E285FC90A02"
    )

    static let glucoseGraph = CBUUID(
        string: "B734F6C1-4713-4E88-A1A6-2E285FC90A03"
    )
}
