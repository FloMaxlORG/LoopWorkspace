//
//  BLECharacteristic.swift
//  Loop
//
//  Created by Florian Maxl on 29.07.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//
//  Defines the data model sent to the ESP32.
//

import CoreBluetooth

final class BLECharacteristic {

    let characteristic: CBMutableCharacteristic

    init(uuid: CBUUID) {

        characteristic = CBMutableCharacteristic(
            type: uuid,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )
    }
}
