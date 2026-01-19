//
//  MyCentralManagerDelegate.swift
//  bluetooth_low_energy_ios
//
//  Created by 闫守旺 on 2023/8/13.
//

import Foundation
import CoreBluetooth

class MyCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
    private let mCentralManager: MyCentralManager

    init(centralManager: MyCentralManager) {
        NSLog("[BLE-Bitchat-Delegate] MyCentralManagerDelegate initialized")
        self.mCentralManager = centralManager
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

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[BLE-Bitchat-Delegate] *** centralManagerDidUpdateState CALLBACK ***")
        print("[BLE-Bitchat-Delegate] State: \(central.state.rawValue) (\(stateDescription(central.state)))")
        NSLog("[BLE-Bitchat-Delegate] *** centralManagerDidUpdateState CALLBACK ***")
        NSLog("[BLE-Bitchat-Delegate] State: \(central.state.rawValue) (\(stateDescription(central.state)))")
        if #available(macOS 10.15, iOS 13.0, *) {
            print("[BLE-Bitchat-Delegate] Authorization status: \(CBCentralManager.authorization.rawValue)")
            NSLog("[BLE-Bitchat-Delegate] Authorization status: \(CBCentralManager.authorization.rawValue)")
        }
        mCentralManager.didUpdateState(central: central)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Note: Detailed logging in MyCentralManager.didDiscover
        mCentralManager.didDiscover(central: central, peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("[BLE-Bitchat-Delegate] *** didConnect CALLBACK *** to: \(peripheral.name ?? "unknown")")
        mCentralManager.didConnect(central: central, peripheral: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLE-Bitchat-Delegate] *** didFailToConnect CALLBACK *** to: \(peripheral.name ?? "unknown")")
        NSLog("[BLE-Bitchat-Delegate] Error: \(error?.localizedDescription ?? "none")")
        mCentralManager.didFailToConnect(central: central, peripheral: peripheral, error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLE-Bitchat-Delegate] *** didDisconnectPeripheral CALLBACK *** from: \(peripheral.name ?? "unknown")")
        if let error = error {
            NSLog("[BLE-Bitchat-Delegate] Error: \(error.localizedDescription)")
        }
        mCentralManager.didDisconnectPeripheral(central: central, peripheral: peripheral, error: error)
    }
}
