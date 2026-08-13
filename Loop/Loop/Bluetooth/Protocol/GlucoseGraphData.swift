//
//  GlucoseGraphData.swift
//  Loop
//
//  Created by Florian Maxl on 11.08.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

struct GlucoseGraphData {

    struct Point {
        var glucose: UInt16

        /// Minutes relative to the current glucose sample.
        ///
        /// Historical values are negative.
        /// Predictions are positive.
        var relativeMinutes: Int16
    }

    static let protocolVersion: UInt8 = 1
    static let packetType: UInt8 = 2

    var history: [Point]
    var prediction: [Point]

    func encoded() -> Data {
        var data = Data()

        data.append(Self.protocolVersion)
        data.append(Self.packetType)

        data.append(
            UInt8(clamping: history.count)
        )

        data.append(
            UInt8(clamping: prediction.count)
        )

        for point in history {
            data.appendLittleEndian(point.glucose)
            data.appendLittleEndian(point.relativeMinutes)
        }

        for point in prediction {
            data.appendLittleEndian(point.glucose)
            data.appendLittleEndian(point.relativeMinutes)
        }

        return data
    }
}
