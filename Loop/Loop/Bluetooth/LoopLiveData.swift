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

    enum Trend: UInt8 {
        case unknown = 0
        case doubleDown = 1
        case singleDown = 2
        case fortyFiveDown = 3
        case flat = 4
        case fortyFiveUp = 5
        case singleUp = 6
        case doubleUp = 7
    }

    static let protocolVersion: UInt8 = 1

    var glucose: UInt16
    var trend: Trend
    var delta: Int8

    /// Insulin on board in hundredths of a unit.
    /// Example: 145 means 1.45 U.
    var iobHundredths: Int16

    var cob: UInt16
    var predictedGlucose: UInt16
    var loopClosed: Bool
    var timestamp: Date

    func encoded() -> Data {
        var data = Data()
        data.reserveCapacity(16)

        data.append(Self.protocolVersion)

        var flags: UInt8 = 0

        if loopClosed {
            flags |= 1 << 0
        }

        data.append(flags)
        data.appendLittleEndian(glucose)
        data.append(trend.rawValue)
        data.append(UInt8(bitPattern: delta))
        data.appendLittleEndian(iobHundredths)
        data.appendLittleEndian(cob)
        data.appendLittleEndian(predictedGlucose)

        let unixTimestamp = UInt32(
            max(0, timestamp.timeIntervalSince1970)
        )

        data.appendLittleEndian(unixTimestamp)

        return data
    }
}
