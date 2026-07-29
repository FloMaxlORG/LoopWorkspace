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

    private override init() {
        super.init()

        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: nil
        )
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
            print("BLE powered on — setting up service")
            setupService()

        case .poweredOff:
            print("BLE powered off")

        case .unauthorized:
            print("BLE unauthorized")

        case .unsupported:
            print("BLE unsupported")

        case .resetting:
            print("BLE resetting")

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
            return
        }

        print("BLE service added successfully: \(service.uuid.uuidString)")

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
}

// MARK: - Service setup

private extension BLEManager {

    func setupService() {
        print("setupService() called")

        peripheralManager.stopAdvertising()
        peripheralManager.removeAllServices()

        let characteristic = CBMutableCharacteristic(
            type: BLEUUIDs.glucose,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable]
        )

        glucoseCharacteristic = characteristic

        let service = CBMutableService(
            type: BLEUUIDs.liveDataService,
            primary: true
        )

        service.characteristics = [characteristic]

        print("Adding BLE service: \(BLEUUIDs.liveDataService.uuidString)")
        peripheralManager.add(service)
    }
}
