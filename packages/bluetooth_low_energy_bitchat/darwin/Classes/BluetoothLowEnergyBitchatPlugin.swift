#if os(iOS)
import Flutter
import UIKit
import CoreBluetooth
#elseif os(macOS)
import Cocoa
import FlutterMacOS
import CoreBluetooth
#else
#error("Unsupported platform.")
#endif

public class BluetoothLowEnergyBitchatPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        NSLog("[BLE-Bitchat-Plugin] ====== PLUGIN REGISTRATION START ======")
        NSLog("[BLE-Bitchat-Plugin] Plugin registering with Flutter...")

#if os(iOS)
        NSLog("[BLE-Bitchat-Plugin] Platform: iOS")
        let messenger = registrar.messenger()
#elseif os(macOS)
        NSLog("[BLE-Bitchat-Plugin] Platform: macOS")
        let messenger = registrar.messenger
#else
#error("Unsupported platform.")
#endif

        // Log Bluetooth authorization status
        if #available(macOS 10.15, iOS 13.0, *) {
            let centralAuth = CBCentralManager.authorization
            let peripheralAuth = CBPeripheralManager.authorization
            NSLog("[BLE-Bitchat-Plugin] CBCentralManager.authorization: \(centralAuth.rawValue) (\(authDescription(centralAuth)))")
            NSLog("[BLE-Bitchat-Plugin] CBPeripheralManager.authorization: \(peripheralAuth.rawValue) (\(authDescription(peripheralAuth)))")
        } else {
            NSLog("[BLE-Bitchat-Plugin] Authorization check not available (requires macOS 10.15+)")
        }

        NSLog("[BLE-Bitchat-Plugin] Creating MyCentralManager...")
        let centralManager = MyCentralManager(messenger: messenger)

        NSLog("[BLE-Bitchat-Plugin] Creating MyPeripheralManager...")
        let peripheralManager = MyPeripheralManager(messenger: messenger)

        NSLog("[BLE-Bitchat-Plugin] Setting up Pigeon API for CentralManager...")
        MyCentralManagerHostAPISetup.setUp(binaryMessenger: messenger, api: centralManager)

        NSLog("[BLE-Bitchat-Plugin] Setting up Pigeon API for PeripheralManager...")
        MyPeripheralManagerHostAPISetup.setUp(binaryMessenger: messenger, api: peripheralManager)

        NSLog("[BLE-Bitchat-Plugin] ====== PLUGIN REGISTRATION COMPLETE ======")
        NSLog("[BLE-Bitchat-Plugin] Note: CBCentralManager NOT created yet (lazy init)")
        NSLog("[BLE-Bitchat-Plugin] It will be created when Dart calls initialize() or getState()")
    }

    @available(macOS 10.15, iOS 13.0, *)
    private static func authDescription(_ auth: CBManagerAuthorization) -> String {
        switch auth {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .allowedAlways: return "allowedAlways"
        @unknown default: return "unknown(\(auth.rawValue))"
        }
    }
}
