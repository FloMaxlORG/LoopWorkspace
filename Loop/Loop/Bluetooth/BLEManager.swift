//
//  BLEManager.swift
//  Loop
//
//  Created by Florian Maxl on 29.07.26.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//
//  Handles the BLE peripheral and advertising.
//

import Foundation
import CoreBluetooth

final class BLEManager: NSObject {

    static let shared = BLEManager()

    private var peripheralManager: CBPeripheralManager!
    private var glucoseCharacteristic: CBMutableCharacteristic?
    private var liveDataCharacteristic: CBMutableCharacteristic?
    private var glucoseGraphCharacteristic: CBMutableCharacteristic?
    private var currentGraphData: GlucoseGraphData?

    private var currentLiveData = LoopLiveData(
        glucose: 0,
        trend: .unknown,
        delta: LoopLiveData.unknownDelta,
        iobHundredths: 0,
        cob: 0,
        predictedGlucose: 0,
        loopClosed: false,
        timestamp: .distantPast
    )
    
    struct CachedPredictionPoint {
        let glucose: UInt16
        let date: Date
    }
    private var cachedPredictionPoints: [CachedPredictionPoint] = []

    private var hasValidLiveData = false
    
    private var graphSubscribers: [UUID: CBCentral] = [:]
    private var graphSequenceID: UInt8 = 0
    private var pendingGraphChunks: [Data] = []
    
    private var pendingNotification: Data?
    private var lastNotifiedPacket: Data?
    
    private var isServiceAdded = false
    
    private override init() {
        super.init()

        print("BLEManager build marker: live-data-v4")
        
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil
        )
    }

    // This is the public function called by the settings toggle.
    func setEnabled(_ enabled: Bool) {
        print("BLE setting changed: \(enabled)")

        BLESettings.isEnabled = enabled

        guard peripheralManager.state == .poweredOn else {
            print("Bluetooth is not powered on yet")
            return
        }

        if enabled {
            enableBLE()
        } else {
            disableBLE()
        }
    }
    
    func updateState(
        _ changes: @escaping (inout LoopLiveData) -> Void
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateState(changes)
            }
            return
        }

        changes(&currentLiveData)

        hasValidLiveData =
            currentLiveData.glucose > 0 &&
            currentLiveData.timestamp.timeIntervalSince1970 > 0

        // Intentionally DO NOT publish here.
    }
    
    func updateGlucoseAndPublish(
        _ changes: @escaping (inout LoopLiveData) -> Void
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateGlucoseAndPublish(changes)
            }
            return
        }

        changes(&currentLiveData)

        hasValidLiveData =
            currentLiveData.glucose > 0 &&
            currentLiveData.timestamp.timeIntervalSince1970 > 0

        guard hasValidLiveData else {
            print("BLE glucose update invalid — packet not published")
            return
        }

        publishCurrentLiveData()
    }
    
    func updateGraphHistory(
        _ history: [GlucoseGraphData.Point],
        referenceDate: Date
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateGraphHistory(
                    history,
                    referenceDate: referenceDate
                )
            }
            return
        }

        let prediction: [GlucoseGraphData.Point] =
            cachedPredictionPoints.compactMap { point in

                let relativeMinutes = Int(
                    point.date
                        .timeIntervalSince(referenceDate)
                        / 60.0
                )

                // Only include prediction points that are
                // actually in the future relative to the
                // current glucose sample.
                guard relativeMinutes > 0 else {
                    return nil
                }

                return GlucoseGraphData.Point(
                    glucose: point.glucose,
                    relativeMinutes: Int16(
                        clamping: relativeMinutes
                    )
                )
            }
        currentGraphData = GlucoseGraphData(
            history: history,
            prediction: prediction
        )

        print(
            "BLE graph prepared — " +
            "\(history.count) history, " +
            "\(prediction.count) prediction"
        )
        sendGraphNotifications()
    }
    
    func updatePredictionGraph(
        _ prediction: [CachedPredictionPoint]
    ) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updatePredictionGraph(prediction)
            }
            return
        }

        cachedPredictionPoints = prediction
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(
        _ peripheral: CBPeripheralManager
    ) {
        print("BLE state changed: \(peripheral.state.rawValue)")

        switch peripheral.state {
        case .poweredOn:
            print("BLE powered on")

            // Restore the saved preference when Bluetooth becomes available.
            if BLESettings.isEnabled {
                enableBLE()
            } else {
                disableBLE()
            }

        case .poweredOff:
            print("BLE powered off")
            isServiceAdded = false

        case .unauthorized:
            print("BLE unauthorized")

        case .unsupported:
            print("BLE unsupported")

        case .resetting:
            print("BLE resetting")
            isServiceAdded = false

        case .unknown:
            print("BLE state unknown")

        @unknown default:
            print("Unknown BLE state")
        }
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        if let error {
            print("BLE service failed to add: \(error.localizedDescription)")
            print("Full BLE service error: \(error)")
            isServiceAdded = false
            return
        }

        print("BLE service added successfully: \(service.uuid.uuidString)")
        isServiceAdded = true
        
        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey: "Loop-BLE",
            CBAdvertisementDataServiceUUIDsKey: [
                BLEUUIDs.liveDataService
            ]
        ])
        print("startAdvertising() called")
    }

    func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error {
            print("BLE advertising failed: \(error.localizedDescription)")
            print("Full advertising error: \(error)")
            return
        }

        print("BLE advertising started successfully")
        print("isAdvertising: \(peripheral.isAdvertising)")
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        let data: Data

        switch request.characteristic.uuid {

        case BLEUUIDs.liveData:
            guard hasValidLiveData else {
                peripheral.respond(
                    to: request,
                    withResult: .unlikelyError
                )
                return
            }

            data = currentLiveData.encoded()

        case BLEUUIDs.glucoseGraph:
            guard let currentGraphData else {
                peripheral.respond(
                    to: request,
                    withResult: .unlikelyError
                )
                return
            }

            data = currentGraphData.encoded()

        default:
            peripheral.respond(
                to: request,
                withResult: .attributeNotFound
            )
            return
        }

        guard request.offset < data.count else {
            peripheral.respond(
                to: request,
                withResult: .invalidOffset
            )
            return
        }

        request.value = data.subdata(
            in: request.offset..<data.count
        )

        peripheral.respond(
            to: request,
            withResult: .success
        )

        print(
            "BLE read \(request.characteristic.uuid.uuidString): " +
            "\(data.count) bytes"
        )
    }
    
    func peripheralManagerIsReady(
        toUpdateSubscribers peripheral: CBPeripheralManager
    ) {

        // Retry regular LiveData notification first.

        if let packet = pendingNotification,
           let liveDataCharacteristic
        {
            let queued =
                peripheral.updateValue(
                    packet,
                    for: liveDataCharacteristic,
                    onSubscribedCentrals: nil
                )

            if queued {
                pendingNotification = nil
                lastNotifiedPacket = packet

                print(
                    "Pending BLE live-data notification sent"
                )
            }
        }

        // Then retry graph chunks.

        guard
            let glucoseGraphCharacteristic,
            !pendingGraphChunks.isEmpty
        else {
            return
        }

        while !pendingGraphChunks.isEmpty {

            let chunk =
                pendingGraphChunks[0]

            let queued =
                peripheral.updateValue(
                    chunk,
                    for: glucoseGraphCharacteristic,
                    onSubscribedCentrals: nil
                )

            guard queued else {
                return
            }

            pendingGraphChunks.removeFirst()
        }

        print(
            "Pending BLE graph chunks sent"
        )
    }
    
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        print(
            "BLE central subscribed to " +
            characteristic.uuid.uuidString
        )

        switch characteristic.uuid {

        case BLEUUIDs.liveData:

            guard hasValidLiveData else {
                print(
                    "BLE subscribed, but no valid glucose data available yet"
                )
                return
            }

            sendCurrentLiveDataNotification(
                force: true
            )

        case BLEUUIDs.glucoseGraph:

            graphSubscribers[central.identifier] =
                central

            print(
                "BLE graph subscriber registered — " +
                "maximumUpdateValueLength: " +
                "\(central.maximumUpdateValueLength)"
            )

            // Give a new subscriber the current graph immediately.
            sendGraphNotifications()

        default:
            break
        }
    }
    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        print(
            "BLE central unsubscribed from " +
            characteristic.uuid.uuidString
        )

        if characteristic.uuid ==
            BLEUUIDs.glucoseGraph
        {
            graphSubscribers.removeValue(
                forKey: central.identifier
            )
        }
    }
    
    func makeGraphChunks(
        payload: Data,
        maximumUpdateValueLength: Int
    ) -> [Data] {

        // Transport header:
        //
        // Byte 0 = transport version
        // Byte 1 = packet type (graph chunk)
        // Byte 2 = sequence ID
        // Byte 3 = chunk index
        // Byte 4 = total chunks

        let headerLength = 5

        guard maximumUpdateValueLength > headerLength else {
            print(
                "BLE graph MTU too small: \(maximumUpdateValueLength)"
            )
            return []
        }

        let payloadPerChunk =
            maximumUpdateValueLength - headerLength

        let totalChunks = Int(
            ceil(
                Double(payload.count) /
                Double(payloadPerChunk)
            )
        )

        guard totalChunks <= Int(UInt8.max) else {
            print(
                "BLE graph requires too many chunks: \(totalChunks)"
            )
            return []
        }

        let sequenceID = graphSequenceID

        graphSequenceID &+= 1

        var chunks: [Data] = []
        chunks.reserveCapacity(totalChunks)

        for chunkIndex in 0..<totalChunks {

            let start =
                chunkIndex * payloadPerChunk

            let end = min(
                start + payloadPerChunk,
                payload.count
            )

            var chunk = Data()

            chunk.append(1)                     // Transport version
            chunk.append(2)                     // Graph chunk
            chunk.append(sequenceID)
            chunk.append(UInt8(chunkIndex))
            chunk.append(UInt8(totalChunks))

            chunk.append(
                payload.subdata(
                    in: start..<end
                )
            )

            chunks.append(chunk)
        }

        return chunks
    }
    
    func sendGraphNotifications() {

        guard BLESettings.isEnabled else {
            return
        }

        guard peripheralManager.state == .poweredOn else {
            return
        }

        guard let glucoseGraphCharacteristic else {
            return
        }

        guard let currentGraphData else {
            return
        }

        guard !graphSubscribers.isEmpty else {
            return
        }

        let graphPayload =
            currentGraphData.encoded()

        for central in graphSubscribers.values {

            let maxLength =
                central.maximumUpdateValueLength

            let chunks = makeGraphChunks(
                payload: graphPayload,
                maximumUpdateValueLength: maxLength
            )

            print(
                "BLE graph sending \(graphPayload.count) bytes " +
                "as \(chunks.count) chunks, MTU payload \(maxLength)"
            )

            for chunk in chunks {

                let queued =
                    peripheralManager.updateValue(
                        chunk,
                        for: glucoseGraphCharacteristic,
                        onSubscribedCentrals: [central]
                    )

                if !queued {

                    print(
                        "BLE graph queue full — saving remaining chunks"
                    )

                    pendingGraphChunks.append(chunk)

                    if let index = chunks.firstIndex(of: chunk) {
                        pendingGraphChunks.append(
                            contentsOf:
                                chunks.dropFirst(index + 1)
                        )
                    }

                    return
                }
            }
        }
    }
    
}

// MARK: - Private BLE lifecycle

private extension BLEManager {

    func enableBLE() {
        guard BLESettings.isEnabled else {
            return
        }

        guard peripheralManager.state == .poweredOn else {
            return
        }

        if isServiceAdded {
            print("BLE service is already installed")

            if !peripheralManager.isAdvertising {
                startAdvertising()
            }

            return
        }

        print("Loop BLE enabled")
        setupService()
    }

    func disableBLE() {
        print("Loop BLE disabled")

        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()

        liveDataCharacteristic = nil
        pendingNotification = nil
        lastNotifiedPacket = nil
        
        glucoseGraphCharacteristic = nil
        currentGraphData = nil
        graphSubscribers.removeAll()
        pendingGraphChunks.removeAll()
        
        isServiceAdded = false
    }

    func setupService() {
        
        guard BLESettings.isEnabled else {
                return
            }

            guard peripheralManager.state == .poweredOn else {
                return
            }

            print("setupService() called")

            peripheralManager.stopAdvertising()
            peripheralManager.removeAllServices()
        
        let liveCharacteristic = CBMutableCharacteristic(
            type: BLEUUIDs.liveData,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

            liveDataCharacteristic = liveCharacteristic

        let graphCharacteristic = CBMutableCharacteristic(
            type: BLEUUIDs.glucoseGraph,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        glucoseGraphCharacteristic = graphCharacteristic
        
            let service = CBMutableService(
                type: BLEUUIDs.liveDataService,
                primary: true
            )

            service.characteristics = [
                liveCharacteristic,
                graphCharacteristic
            ]

            print("Adding BLE service: \(BLEUUIDs.liveDataService.uuidString)"
            )
        
            peripheralManager.add(service)
        }

    func startAdvertising() {
        guard BLESettings.isEnabled else {
            print("Advertising not started because BLE is disabled")
            return
        }

        guard peripheralManager.state == .poweredOn else {
            print("Advertising not started because Bluetooth is unavailable")
            return
        }

        guard isServiceAdded else {
            print("Advertising not started because service is not ready")
            return
        }

        guard !peripheralManager.isAdvertising else {
            print("BLE is already advertising")
            return
        }

        peripheralManager.startAdvertising([
            CBAdvertisementDataLocalNameKey: "Loop-BLE",
            CBAdvertisementDataServiceUUIDsKey: [
                BLEUUIDs.liveDataService
            ]
        ])

        print("startAdvertising() called")
    }
    
    func publishCurrentLiveData() {
        guard BLESettings.isEnabled else {
            return
        }
        
        guard hasValidLiveData else {

            return

        }

        guard peripheralManager.state == .poweredOn else {
            return
        }

        guard liveDataCharacteristic != nil else {
            return
        }

        sendCurrentLiveDataNotification()
    }
    
    func sendCurrentLiveDataNotification(
        force: Bool = false
    ) {
        guard peripheralManager.state == .poweredOn else {
            return
        }

        guard let liveDataCharacteristic else {
            return
        }

        guard hasValidLiveData else {
            return
        }

        let packet = currentLiveData.encoded()

        // Don't send the exact same state repeatedly.
        if !force,
           let lastNotifiedPacket,
           lastNotifiedPacket == packet
        {
            print("BLE notification skipped: packet unchanged")
            return
        }

        let wasQueued = peripheralManager.updateValue(
            packet,
            for: liveDataCharacteristic,
            onSubscribedCentrals: nil
        )

        if wasQueued {
            pendingNotification = nil
            lastNotifiedPacket = packet

            print(
                "\nBLE live-data notification sent at \(currentLiveData.timestamp.formatted())\n" +
                "-----------------------------------------\n" +
                "Current BG: \(currentLiveData.glucose) mg/dL\n" +
                "Prediction: \(currentLiveData.predictedGlucose) mg/dL\n" +
                "Trend: \(String(describing:(currentLiveData.trend)))\n" +
                "Delta: \(currentLiveData.delta) mg/dL\n" +
                "IOB: \(Double(currentLiveData.iobHundredths) / 100.0)\n" +
                "COB: \(currentLiveData.cob)\n" +
                "Closed Loop: \(currentLiveData.loopClosed)\n" +
                "-----------------------------------------\n"
                    )
        } else {
            pendingNotification = packet
            print("BLE notification queue full; waiting to retry")
        }
    }}
