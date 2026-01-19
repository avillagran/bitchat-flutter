//
//  MyPeripheralManagerDelegate.swift
//  bluetooth_low_energy_darwin
//
//  Created by 闫守旺 on 2023/10/7.
//

import Foundation
import CoreBluetooth

class MyPeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
    private let mPeripheralManager: MyPeripheralManager

    init(peripheralManager: MyPeripheralManager) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] MyPeripheralManagerDelegate initialized")
        self.mPeripheralManager = peripheralManager
    }

    private func stateDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** peripheralManagerDidUpdateState CALLBACK ***")
        NSLog("[BLE-Bitchat-PeripheralDelegate] State: \(peripheral.state.rawValue) (\(stateDescription(peripheral.state)))")
        if #available(macOS 10.15, iOS 13.0, *) {
            NSLog("[BLE-Bitchat-PeripheralDelegate] Authorization status: \(CBPeripheralManager.authorization.rawValue)")
        }
        mPeripheralManager.didUpdateState(peripheral: peripheral)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** didAdd service CALLBACK *** UUID: \(service.uuid.uuidString)")
        if let error = error {
            NSLog("[BLE-Bitchat-PeripheralDelegate] Error: \(error.localizedDescription)")
        }
        mPeripheralManager.didAdd(peripheral: peripheral, service: service, error: error)
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** peripheralManagerDidStartAdvertising CALLBACK ***")
        if let error = error {
            NSLog("[BLE-Bitchat-PeripheralDelegate] Error: \(error.localizedDescription)")
        } else {
            NSLog("[BLE-Bitchat-PeripheralDelegate] Advertising started successfully")
        }
        mPeripheralManager.didStartAdvertising(peripheral: peripheral, error: error)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** didReceiveRead CALLBACK ***")
        mPeripheralManager.didReceiveRead(peripheral: peripheral, request: request)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** didReceiveWrite CALLBACK *** count: \(requests.count)")
        mPeripheralManager.didReceiveWrite(peripheral: peripheral, requests: requests)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** didSubscribeTo CALLBACK *** char: \(characteristic.uuid.uuidString)")
        mPeripheralManager.didSubscribeTo(peripheral: peripheral, central: central, characteristic: characteristic)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** didUnsubscribeFrom CALLBACK *** char: \(characteristic.uuid.uuidString)")
        mPeripheralManager.didUnsubscribeFrom(peripheral: peripheral, central: central, characteristic: characteristic)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        NSLog("[BLE-Bitchat-PeripheralDelegate] *** isReadyToUpdateSubscribers CALLBACK ***")
        mPeripheralManager.isReadyToUpdateSubscribers(peripheral: peripheral)
    }
}
