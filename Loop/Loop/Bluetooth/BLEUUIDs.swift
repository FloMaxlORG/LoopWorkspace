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

    // MARK: - Service

    static let liveDataService = CBUUID(

        string: "6D6F6F70-0001-4C4F-4F50-424C454C4F50"

    )

    // MARK: - Characteristics

    static let glucose = CBUUID(

        string: "6D6F6F70-0002-4C4F-4F50-424C454C4F50"

    )

    static let trend = CBUUID(

        string: "6D6F6F70-0003-4C4F-4F50-424C454C4F50"

    )

    static let delta = CBUUID(

        string: "6D6F6F70-0004-4C4F-4F50-424C454C4F50"

    )

    static let iob = CBUUID(

        string: "6D6F6F70-0005-4C4F-4F50-424C454C4F50"

    )

    static let cob = CBUUID(

        string: "6D6F6F70-0006-4C4F-4F50-424C454C4F50"

    )

    static let prediction = CBUUID(

        string: "6D6F6F70-0007-4C4F-4F50-424C454C4F50"

    )

    static let status = CBUUID(

        string: "6D6F6F70-0008-4C4F-4F50-424C454C4F50"

    )

}
