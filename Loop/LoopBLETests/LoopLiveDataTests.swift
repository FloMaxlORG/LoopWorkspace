//
//  LoopBLETests.swift
//  LoopBLETests
//
//  Created by Florian Maxl on 05.08.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import Loop

final class LoopLiveDataTests: XCTestCase {

    func testEncodedPacketHasExpectedLength() {
        let liveData = makeTestLiveData()

        let packet = liveData.encoded()

        XCTAssertEqual(packet.count, 17)
    }

    func testEncodedPacketMatchesProtocolLayout() {
        let liveData = makeTestLiveData()

        let packet = liveData.encoded()

        let expectedBytes: [UInt8] = [
            0x01,             // Protocol version
            0x01,             // Packet type: live data
            0x01,             // Flags: closed loop
            0x7B, 0x00,       // Glucose: 123 mg/dL
            0x04,             // Trend: flat
            0x02,             // Delta: +2 mg/dL
            0x91, 0x00,       // IOB: 145 = 1.45 U
            0x12, 0x00,       // COB: 18 g
            0x76, 0x00,       // Predicted glucose: 118 mg/dL
            0xE8, 0x03, 0x00, 0x00 // Timestamp: 1000
        ]

        XCTAssertEqual(Array(packet), expectedBytes)
    }

    func testOpenLoopClearsClosedLoopFlag() {
        var liveData = makeTestLiveData()
        liveData.loopClosed = false

        let packet = liveData.encoded()

        XCTAssertEqual(packet[2] & 0b0000_0001, 0)
    }

    func testClosedLoopSetsClosedLoopFlag() {
        var liveData = makeTestLiveData()
        liveData.loopClosed = true

        let packet = liveData.encoded()

        XCTAssertEqual(packet[2] & 0b0000_0001, 1)
    }

    func testNegativeDeltaUsesSignedByteRepresentation() {
        var liveData = makeTestLiveData()
        liveData.delta = -5

        let packet = liveData.encoded()

        XCTAssertEqual(packet[6], 0xFB)
    }

    func testNegativeIOBUsesSignedLittleEndianRepresentation() {
        var liveData = makeTestLiveData()
        liveData.iobHundredths = -25

        let packet = liveData.encoded()

        XCTAssertEqual(packet[7], 0xE7)
        XCTAssertEqual(packet[8], 0xFF)
    }

    func testTimestampUsesLittleEndianEncoding() {
        var liveData = makeTestLiveData()
        liveData.timestamp = Date(timeIntervalSince1970: 0x1234_5678)

        let packet = liveData.encoded()

        XCTAssertEqual(
            Array(packet[13...16]),
            [0x78, 0x56, 0x34, 0x12]
        )
    }

    func testAllTrendValuesEncodeToExpectedByte() {
        let trends: [(LoopLiveData.Trend, UInt8)] = [
            (.unknown, 0),
            (.doubleDown, 1),
            (.singleDown, 2),
            (.fortyFiveDown, 3),
            (.flat, 4),
            (.fortyFiveUp, 5),
            (.singleUp, 6),
            (.doubleUp, 7)
        ]

        for (trend, expectedByte) in trends {
            var liveData = makeTestLiveData()
            liveData.trend = trend

            let packet = liveData.encoded()

            XCTAssertEqual(
                packet[5],
                expectedByte,
                "Unexpected encoded value for \(trend)"
            )
        }
    }

    private func makeTestLiveData() -> LoopLiveData {
        LoopLiveData(
            glucose: 123,
            trend: .flat,
            delta: 2,
            iobHundredths: 145,
            cob: 18,
            predictedGlucose: 118,
            loopClosed: true,
            timestamp: Date(timeIntervalSince1970: 1000)
        )
    }
}
