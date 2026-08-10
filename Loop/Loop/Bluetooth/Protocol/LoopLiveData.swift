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

    enum PacketType: UInt8 {
        case liveData = 1
    }

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
    static let encodedLength = 17

    /// Reserved value meaning that no valid delta is currently available.
    static let unknownDelta: Int8 = .min

    var packetType: PacketType = .liveData

    /// Current glucose in mg/dL.
    var glucose: UInt16

    /// CGM trend direction.
    var trend: Trend

    /// Change from the previous glucose sample in mg/dL.
    ///
    /// Valid range:
    /// -127...127 = delta in mg/dL
    /// -128 = unavailable
    var delta: Int8

    /// Insulin on board in hundredths of a unit.
    ///
    /// Example:
    /// 145 = 1.45 U
    var iobHundredths: Int16

    /// Carbs on board in grams.
    var cob: UInt16

    /// Predicted glucose in mg/dL.
    var predictedGlucose: UInt16

    /// Whether closed-loop operation is enabled.
    var loopClosed: Bool

    /// Timestamp belonging to the current glucose sample.
    var timestamp: Date

    func encoded() -> Data {
        var data = Data()

        data.reserveCapacity(Self.encodedLength)

        // Byte 0
        // Protocol version
        data.append(Self.protocolVersion)

        // Byte 1
        // Packet type
        data.append(packetType.rawValue)

        // Byte 2
        // Flags
        var flags: UInt8 = 0

        if loopClosed {
            flags |= 1 << 0
        }

        data.append(flags)

        // Bytes 3-4
        // Current glucose
        data.appendLittleEndian(glucose)

        // Byte 5
        // Trend
        data.append(trend.rawValue)

        // Byte 6
        // Delta
        data.append(UInt8(bitPattern: delta))

        // Bytes 7-8
        // IOB × 100
        data.appendLittleEndian(iobHundredths)

        // Bytes 9-10
        // COB
        data.appendLittleEndian(cob)

        // Bytes 11-12
        // Predicted glucose
        data.appendLittleEndian(predictedGlucose)

        // Bytes 13-16
        // Unix timestamp
        let timestampSeconds = max(
            0,
            min(
                timestamp.timeIntervalSince1970,
                Double(UInt32.max)
            )
        )

        data.appendLittleEndian(
            UInt32(timestampSeconds)
        )

        assert(
            data.count == Self.encodedLength,
            "Unexpected BLE live-data packet length: \(data.count)"
        )

        return data
    }
}
