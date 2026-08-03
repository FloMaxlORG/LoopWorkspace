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

    private var currentLiveData = LoopLiveData(
        glucose: 125,
        trend: .flat,
        delta: 2,
        iobHundredths: 145,
        cob: 18,
        predictedGlucose: 118,
        loopClosed: true,
        timestamp: Date()
    )

    private var pendingNotification: Data?
    
    private var isServiceAdded = false
    
    private override init() {
        super.init()

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
    
    func updateLiveData(_ liveData: LoopLiveData) {
        currentLiveData = liveData

        guard BLESettings.isEnabled else {
            return
        }

        sendCurrentLiveDataNotification()
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
        startAdvertising()
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
        print(
            "BLE read request received for " +
            request.characteristic.uuid.uuidString
        )

        guard request.characteristic.uuid == BLEUUIDs.liveData else {
            peripheral.respond(
                to: request,
                withResult: .attributeNotFound
            )
            return
        }
        
        let packet = currentLiveData.encoded()

        guard request.offset >= 0, request.offset < packet.count else {
            peripheral.respond(
                to: request,
                withResult: .invalidOffset
            )
            return
        }

        request.value = packet.subdata(
            in: request.offset..<packet.count
        )

        peripheral.respond(
            to: request,
            withResult: .success
        )

        print("BLE read returned \(packet.count) bytes")
    }
    
    func peripheralManagerIsReady(
        toUpdateSubscribers peripheral: CBPeripheralManager
    ) {
        guard
            let packet = pendingNotification,
            let liveDataCharacteristic
        else {
            return
        }

        let wasQueued = peripheral.updateValue(
            packet,
            for: liveDataCharacteristic,
            onSubscribedCentrals: nil
        )

        if wasQueued {
            pendingNotification = nil
            print("Pending BLE notification sent")
        }
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

        guard characteristic.uuid == BLEUUIDs.liveData else {
            return
        }

        sendCurrentLiveDataNotification()
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
        
        let characteristic = CBMutableCharacteristic(
            type: BLEUUIDs.liveData,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

            liveDataCharacteristic = characteristic

            let service = CBMutableService(
                type: BLEUUIDs.liveDataService,
                primary: true
            )

            service.characteristics = [characteristic]

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
    
    func sendCurrentLiveDataNotification() {
        guard peripheralManager.state == .poweredOn else {
            return
        }

        guard let liveDataCharacteristic else {
            return
        }

        let packet = currentLiveData.encoded()

        let wasQueued = peripheralManager.updateValue(
            packet,
            for: liveDataCharacteristic,
            onSubscribedCentrals: nil
        )

        if wasQueued {
            pendingNotification = nil

            print(
                "BLE live-data notification sent: " +
                "\(currentLiveData.glucose) mg/dL"
            )
        } else {
            pendingNotification = packet
            print("BLE notification queue is full; waiting to retry")
        }
    }

}
