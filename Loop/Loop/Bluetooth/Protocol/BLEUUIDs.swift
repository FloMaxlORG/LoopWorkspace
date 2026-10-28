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
        string: "6D6F6F70-0001-4C4F-4F50-424C454C4F50"
    )

    static let liveData = CBUUID(
        string: "6D6F6F70-0002-4C4F-4F50-424C454C4F50"
    )
}
