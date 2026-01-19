//
//  MyCentralController.swift
//  bluetooth_low_energy_ios
//
//  Created by 闫守旺 on 2023/8/13.
//
//  Modified for bluetooth_low_energy_bitchat: lazy CBCentralManager initialization
//  to fix macOS TCC crash on app startup.
//

import Foundation
import CoreBluetooth

#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#else
#error("Unsupported platform.")
#endif

class MyCentralManager: MyCentralManagerHostAPI {
    private let mAPI: MyCentralManagerFlutterAPI
    // LAZY INIT: CBCentralManager is now optional and created on first use
    private var mCentralManager: CBCentralManager?

    private lazy var mCentralManagerDelegate = MyCentralManagerDelegate(centralManager: self)
    private lazy var peripheralDelegate = MyPeripheralDelegate(centralManager: self)

    private var mPeripherals: [String: CBPeripheral]
    private var mServices: [String: [Int64: CBService]]
    private var mCharacteristics: [String: [Int64: CBCharacteristic]]
    private var mDescriptors: [String: [Int64: CBDescriptor]]

    private var mConnectCompletions: [String: (Result<Void, Error>) -> Void]
    private var mDisconnectCompletions: [String: (Result<Void, Error>) -> Void]
    private var mReadRSSICompletions: [String: (Result<Int64, Error>) -> Void]
    private var mDiscoverServicesCompletions: [String: (Result<[MyGATTServiceArgs], Error>) -> Void]
    private var mDiscoverIncludedServicesCompletions: [String: [Int64: (Result<[MyGATTServiceArgs], Error>) -> Void]]
    private var mDiscoverCharacteristicsCompletions: [String: [Int64: (Result<[MyGATTCharacteristicArgs], Error>) -> Void]]
    private var mDiscoverDescriptorsCompletions: [String: [Int64: (Result<[MyGATTDescriptorArgs], Error>) -> Void]]
    private var mReadCharacteristicCompletions: [String: [Int64: (Result<FlutterStandardTypedData, Error>) -> Void]]
    private var mWriteCharacteristicCompletions: [String: [Int64: (Result<Void, Error>) -> Void]]
    private var mSetCharacteristicNotifyStateCompletions: [String: [Int64: (Result<Void, Error>) -> Void]]
    private var mReadDescriptorCompletions: [String: [Int64: (Result<FlutterStandardTypedData, Error>) -> Void]]
    private var mWriteDescriptorCompletions: [String: [Int64: (Result<Void, Error>) -> Void]]

    // Track last logged discovery time for each UUID to reduce log spam
    private var mLastDiscoveryLogTime: [String: Date] = [:]
    private let discoveryLogThrottleSeconds: TimeInterval = 30

    init(messenger: FlutterBinaryMessenger) {
        mAPI = MyCentralManagerFlutterAPI(binaryMessenger: messenger)
        // LAZY INIT: DO NOT create CBCentralManager here - it triggers TCC immediately
        // mCentralManager will be created in getCentralManager() on first use

        mPeripherals = [:]
        mServices = [:]
        mCharacteristics = [:]
        mDescriptors = [:]

        mConnectCompletions = [:]
        mDisconnectCompletions = [:]
        mReadRSSICompletions = [:]
        mDiscoverServicesCompletions = [:]
        mDiscoverIncludedServicesCompletions = [:]
        mDiscoverCharacteristicsCompletions = [:]
        mDiscoverDescriptorsCompletions = [:]
        mReadCharacteristicCompletions = [:]
        mWriteCharacteristicCompletions = [:]
        mSetCharacteristicNotifyStateCompletions = [:]
        mReadDescriptorCompletions = [:]
        mWriteDescriptorCompletions = [:]
    }

    private var pollTimer: Timer?

    // LAZY INIT: Get or create CBCentralManager on demand
    // IMPORTANT: Must pass delegate at creation time to receive initial centralManagerDidUpdateState
    private func getCentralManager() -> CBCentralManager {
        if mCentralManager == nil {
            NSLog("[BLE-Bitchat] Creating CBCentralManager with delegate... isMainThread=\(Thread.isMainThread)")
            print("[BLE-Bitchat] Creating CBCentralManager with delegate... isMainThread=\(Thread.isMainThread)")
            mCentralManager = CBCentralManager(delegate: mCentralManagerDelegate, queue: DispatchQueue.main)
            NSLog("[BLE-Bitchat] CBCentralManager created, state: \(mCentralManager!.state.rawValue)")

            // DEBUG: Background poll disabled - was causing SIGABRT
        }
        return mCentralManager!
    }

    func initialize() throws {
        NSLog("[BLE-Bitchat] ====== CENTRAL INITIALIZE START ======")
        NSLog("[BLE-Bitchat] initialize() called from Dart")

        // LAZY INIT: CBCentralManager is created here when Dart calls initialize()
        let centralManager = getCentralManager()
        NSLog("[BLE-Bitchat] After getCentralManager, state: \(centralManager.state.rawValue) (\(stateDescription(centralManager.state)))")

        if(centralManager.isScanning) {
            NSLog("[BLE-Bitchat] Stopping existing scan")
            centralManager.stopScan()
        }

        let connectedCount = mPeripherals.values.filter { $0.state != .disconnected }.count
        NSLog("[BLE-Bitchat] Disconnecting \(connectedCount) connected peripherals")
        for peripheral in mPeripherals.values {
            if peripheral.state != .disconnected {
                centralManager.cancelPeripheralConnection(peripheral)
            }
        }

        mPeripherals.removeAll()
        mServices.removeAll()
        mCharacteristics.removeAll()
        mDescriptors.removeAll()

        mConnectCompletions.removeAll()
        mDisconnectCompletions.removeAll()
        mReadRSSICompletions.removeAll()
        mDiscoverServicesCompletions.removeAll()
        mDiscoverIncludedServicesCompletions.removeAll()
        mDiscoverCharacteristicsCompletions.removeAll()
        mDiscoverDescriptorsCompletions.removeAll()
        mReadCharacteristicCompletions.removeAll()
        mWriteCharacteristicCompletions.removeAll()
        mSetCharacteristicNotifyStateCompletions.removeAll()
        mReadDescriptorCompletions.removeAll()
        mWriteDescriptorCompletions.removeAll()

        // Clear discovery log tracking on reset
        mLastDiscoveryLogTime.removeAll()

        centralManager.delegate = mCentralManagerDelegate
        NSLog("[BLE-Bitchat] Delegate reassigned, current state: \(centralManager.state.rawValue) (\(stateDescription(centralManager.state)))")
        NSLog("[BLE-Bitchat] ====== CENTRAL INITIALIZE COMPLETE ======")
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

    func getState() throws -> MyBluetoothLowEnergyStateArgs {
        let state = getCentralManager().state
        NSLog("[BLE-Bitchat] getState() called, returning: \(state.rawValue) (\(stateDescription(state)))")
        let stateArgs = state.toArgs()
        return stateArgs
    }

    func showAppSettings(completion: @escaping (Result<Void, any Error>) -> Void) {
#if os(iOS)
        do {
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                throw MyError.illegalArgument
            }
            UIApplication.shared.open(url) { success in
                if (success) {
                    completion(.success(()))
                } else {
                    completion(.failure(MyError.unknown))
                }
            }
        } catch {
            completion(.failure(error))
        }
#else
        completion(.failure(MyError.unsupported))
#endif
    }

    func startDiscovery(serviceUUIDsArgs: [String]) throws {
        NSLog("[BLE-Bitchat] ====== START DISCOVERY ======")
        let currentState = getCentralManager().state
        NSLog("[BLE-Bitchat] Current state before scan: \(currentState.rawValue) (\(stateDescription(currentState)))")

        if currentState != .poweredOn {
            NSLog("[BLE-Bitchat] WARNING: Attempting to scan while not poweredOn!")
        }

        let serviceUUIDs = serviceUUIDsArgs.isEmpty ? nil : serviceUUIDsArgs.map { serviceUUIDArgs in serviceUUIDArgs.toCBUUID() }
        NSLog("[BLE-Bitchat] Service UUIDs filter: \(serviceUUIDs?.map { $0.uuidString } ?? ["none (scanning all)"])")

        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        NSLog("[BLE-Bitchat] Calling scanForPeripherals...")
        getCentralManager().scanForPeripherals(withServices: serviceUUIDs, options: options)

        NSLog("[BLE-Bitchat] scanForPeripherals called, isScanning: \(getCentralManager().isScanning)")
    }

    func stopDiscovery() throws {
        NSLog("[BLE-Bitchat] stopDiscovery() called, isScanning was: \(getCentralManager().isScanning)")
        getCentralManager().stopScan()
        NSLog("[BLE-Bitchat] stopScan completed")
    }

    func retrieveConnectedPeripherals() throws -> [MyPeripheralArgs] {
        let peripherals = getCentralManager().retrieveConnectedPeripherals(withServices: [])
        let peripheralsArgs = peripherals.map { peripheral in
            let peripheralArgs = peripheral.toArgs()
            let uuidArgs = peripheralArgs.uuidArgs
            if peripheral.delegate == nil {
                peripheral.delegate = peripheralDelegate
            }
            self.mPeripherals[uuidArgs] = peripheral
            return peripheralArgs
        }
        return peripheralsArgs
    }

    func connect(uuidArgs: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[BLE-Bitchat] ====== CONNECT START ======")
        NSLog("[BLE-Bitchat] Connecting to peripheral: \(uuidArgs)")
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            NSLog("[BLE-Bitchat] Peripheral found, name: \(peripheral.name ?? "unknown"), state: \(peripheral.state.rawValue)")
            getCentralManager().connect(peripheral)
            mConnectCompletions[uuidArgs] = completion
            NSLog("[BLE-Bitchat] connect() called, waiting for delegate callback")
        } catch {
            NSLog("[BLE-Bitchat] ERROR: Failed to connect - \(error)")
            completion(.failure(error))
        }
    }

    func disconnect(uuidArgs: String, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[BLE-Bitchat] ====== DISCONNECT START ======")
        NSLog("[BLE-Bitchat] Disconnecting from peripheral: \(uuidArgs)")
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            NSLog("[BLE-Bitchat] Peripheral found, current state: \(peripheral.state.rawValue)")
            getCentralManager().cancelPeripheralConnection(peripheral)
            mDisconnectCompletions[uuidArgs] = completion
            NSLog("[BLE-Bitchat] cancelPeripheralConnection() called")
        } catch {
            NSLog("[BLE-Bitchat] ERROR: Failed to disconnect - \(error)")
            completion(.failure(error))
        }
    }

    func getMaximumWriteLength(uuidArgs: String, typeArgs: MyGATTCharacteristicWriteTypeArgs) throws -> Int64 {
        let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
        let type = typeArgs.toWriteType()
        let maximumWriteLength = peripheral.maximumWriteValueLength(for: type)
        let maximumWriteLengthArgs = maximumWriteLength.toInt64()
        return maximumWriteLengthArgs
    }

    func readRSSI(uuidArgs: String, completion: @escaping (Result<Int64, Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            peripheral.readRSSI()
            mReadRSSICompletions[uuidArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func discoverServices(uuidArgs: String, completion: @escaping (Result<[MyGATTServiceArgs], Error>) -> Void) {
        NSLog("[BLE-Bitchat] ====== DISCOVER SERVICES START ======")
        NSLog("[BLE-Bitchat] discoverServices called for: \(uuidArgs)")
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            NSLog("[BLE-Bitchat] Peripheral found: \(peripheral.name ?? "unknown"), state: \(peripheral.state.rawValue)")
            NSLog("[BLE-Bitchat] Peripheral state description: \(peripheralStateDescription(peripheral.state))")
            NSLog("[BLE-Bitchat] Calling peripheral.discoverServices(nil)...")
            peripheral.discoverServices(nil)
            mDiscoverServicesCompletions[uuidArgs] = completion
            NSLog("[BLE-Bitchat] discoverServices() called, waiting for didDiscoverServices callback...")
        } catch {
            NSLog("[BLE-Bitchat] ERROR: discoverServices failed - \(error)")
            completion(.failure(error))
        }
    }

    private func peripheralStateDescription(_ state: CBPeripheralState) -> String {
        switch state {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        case .disconnecting: return "disconnecting"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }

    func discoverIncludedServices(uuidArgs: String, hashCodeArgs: Int64, completion: @escaping (Result<[MyGATTServiceArgs], Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let service = try retrieveService(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            peripheral.discoverIncludedServices(nil, for: service)
            mDiscoverIncludedServicesCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func discoverCharacteristics(uuidArgs: String, hashCodeArgs: Int64, completion: @escaping (Result<[MyGATTCharacteristicArgs], Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let service = try retrieveService(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            peripheral.discoverCharacteristics(nil, for: service)
            mDiscoverCharacteristicsCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func discoverDescriptors(uuidArgs: String, hashCodeArgs: Int64, completion: @escaping (Result<[MyGATTDescriptorArgs], Error>) -> Void){
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let characteristic = try retrieveCharacteristic(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            peripheral.discoverDescriptors(for: characteristic)
            mDiscoverDescriptorsCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func readCharacteristic(uuidArgs: String, hashCodeArgs: Int64, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let characteristic = try retrieveCharacteristic(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            peripheral.readValue(for: characteristic)
            mReadCharacteristicCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func writeCharacteristic(uuidArgs: String, hashCodeArgs: Int64, valueArgs: FlutterStandardTypedData, typeArgs: MyGATTCharacteristicWriteTypeArgs, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let characteristic = try retrieveCharacteristic(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            let data = valueArgs.data
            let type = typeArgs.toWriteType()
            peripheral.writeValue(data, for: characteristic, type: type)
            if type == .withResponse {
                mWriteCharacteristicCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
            } else {
                completion(.success(()))
            }
        } catch {
            completion(.failure(error))
        }
    }

    func setCharacteristicNotifyState(uuidArgs: String, hashCodeArgs: Int64, stateArgs: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let characteristic = try retrieveCharacteristic(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            let enabled = stateArgs
            peripheral.setNotifyValue(enabled, for: characteristic)
            mSetCharacteristicNotifyStateCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func readDescriptor(uuidArgs: String, hashCodeArgs: Int64, completion: @escaping (Result<FlutterStandardTypedData, Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let descriptor = try retrieveDescriptor(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            peripheral.readValue(for: descriptor)
            mReadDescriptorCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func writeDescriptor(uuidArgs: String, hashCodeArgs: Int64, valueArgs: FlutterStandardTypedData, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let peripheral = try retrievePeripheral(uuidArgs: uuidArgs)
            let descriptor = try retrieveDescriptor(uuidArgs: uuidArgs, hashCodeArgs: hashCodeArgs)
            let data = valueArgs.data
            peripheral.writeValue(data, for: descriptor)
            mWriteDescriptorCompletions[uuidArgs, default: [:]][hashCodeArgs] = completion
        } catch {
            completion(.failure(error))
        }
    }

    func didUpdateState(central: CBCentralManager) {
        let state = central.state
        NSLog("[BLE-Bitchat] ====== STATE UPDATE ======")
        NSLog("[BLE-Bitchat] didUpdateState received: \(state.rawValue) (\(stateDescription(state)))")
        let stateArgs = state.toArgs()
        NSLog("[BLE-Bitchat] Notifying Dart of state change...")
        mAPI.onStateChanged(stateArgs: stateArgs) { result in
            switch result {
            case .success:
                NSLog("[BLE-Bitchat] State change notification sent to Dart successfully")
            case .failure(let error):
                NSLog("[BLE-Bitchat] ERROR: Failed to notify Dart of state change: \(error)")
            }
        }
    }

    func didDiscover(central: CBCentralManager, peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        let peripheralArgs = peripheral.toArgs()
        let uuidArgs = peripheralArgs.uuidArgs
        let rssiArgs = rssi.int64Value
        let advertisementArgs = advertisementData.toAdvertisementArgs()

        // Only log if this is first discovery or hasn't been logged in the last 30 seconds
        let now = Date()
        let shouldLog: Bool
        if let lastLogTime = mLastDiscoveryLogTime[uuidArgs] {
            shouldLog = now.timeIntervalSince(lastLogTime) >= discoveryLogThrottleSeconds
        } else {
            shouldLog = true // First discovery
        }

        if shouldLog {
            NSLog("[BLE-Bitchat] DISCOVERED: \(peripheral.name ?? "unknown") UUID: \(uuidArgs) RSSI: \(rssiArgs)")
            mLastDiscoveryLogTime[uuidArgs] = now
        }

        if peripheral.delegate == nil {
            peripheral.delegate = peripheralDelegate
        }
        mPeripherals[uuidArgs] = peripheral
        mAPI.onDiscovered(peripheralArgs: peripheralArgs, rssiArgs: rssiArgs, advertisementArgs: advertisementArgs) { result in
            switch result {
            case .success:
                break // Don't spam logs for every discovery
            case .failure(let error):
                NSLog("[BLE-Bitchat] ERROR: Failed to notify Dart of discovery: \(error)")
            }
        }
    }

    func didConnect(central: CBCentralManager, peripheral: CBPeripheral) {
        NSLog("[BLE-Bitchat] ====== CONNECTED ======")
        let peripheralArgs = peripheral.toArgs()
        let uuidArgs = peripheralArgs.uuidArgs
        NSLog("[BLE-Bitchat] Connected to: \(peripheral.name ?? "unknown") UUID: \(uuidArgs)")
        let stateArgs = MyConnectionStateArgs.connected
        mAPI.onConnectionStateChanged(peripheralArgs: peripheralArgs, stateArgs: stateArgs) { _ in }
        guard let completion = mConnectCompletions.removeValue(forKey: uuidArgs) else {
            NSLog("[BLE-Bitchat] No completion handler for connection (unexpected)")
            return
        }
        NSLog("[BLE-Bitchat] Calling connection completion handler")
        completion(.success(()))
    }

    func didFailToConnect(central: CBCentralManager, peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLE-Bitchat] ====== CONNECTION FAILED ======")
        let uuidArgs = peripheral.identifier.toArgs()
        NSLog("[BLE-Bitchat] Failed to connect to: \(peripheral.name ?? "unknown") UUID: \(uuidArgs)")
        NSLog("[BLE-Bitchat] Error: \(error?.localizedDescription ?? "unknown error")")
        guard let completion = mConnectCompletions.removeValue(forKey: uuidArgs) else {
            NSLog("[BLE-Bitchat] No completion handler for failed connection")
            return
        }
        completion(.failure(error ?? MyError.unknown))
    }

    func didDisconnectPeripheral(central: CBCentralManager, peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLE-Bitchat] ====== DISCONNECTED ======")
        let peripheralArgs = peripheral.toArgs()
        let uuidArgs = peripheralArgs.uuidArgs
        NSLog("[BLE-Bitchat] Disconnected from: \(peripheral.name ?? "unknown") UUID: \(uuidArgs)")
        if let error = error {
            NSLog("[BLE-Bitchat] Disconnect error: \(error.localizedDescription)")
        }
        mServices.removeValue(forKey: uuidArgs)
        mCharacteristics.removeValue(forKey: uuidArgs)
        mDescriptors.removeValue(forKey: uuidArgs)
        let errorNotNil = error ?? MyError.unknown
        let readRssiCompletion = mReadRSSICompletions.removeValue(forKey: uuidArgs)
        readRssiCompletion?(.failure(errorNotNil))
        let discoverServicesCompletion = mDiscoverServicesCompletions.removeValue(forKey: uuidArgs)
        discoverServicesCompletion?(.failure(errorNotNil))
        let discoverIncludedServicesCompletions = self.mDiscoverIncludedServicesCompletions.removeValue(forKey: uuidArgs)
        if discoverIncludedServicesCompletions != nil {
            let completions = discoverIncludedServicesCompletions!.values
            for completion in completions {
                completion(.failure(errorNotNil))
            }
        }
        let discoverCharacteristicsCompletions = self.mDiscoverCharacteristicsCompletions.removeValue(forKey: uuidArgs)
        if discoverCharacteristicsCompletions != nil {
            let completions = discoverCharacteristicsCompletions!.values
            for completion in completions {
                completion(.failure(errorNotNil))
            }
        }
        let discoverDescriptorsCompletions = self.mDiscoverDescriptorsCompletions.removeValue(forKey: uuidArgs)
        if discoverDescriptorsCompletions != nil {
            let completions = discoverDescriptorsCompletions!.values
            for completion in completions {
                completion(.failure(errorNotNil))
            }
        }
        let readCharacteristicCompletions = self.mReadCharacteristicCompletions.removeValue(forKey: uuidArgs)
        if readCharacteristicCompletions != nil {
            let completions = readCharacteristicCompletions!.values
            for completion in completions {
                completion(.failure(errorNotNil))
            }
        }
        let writeCharacteristicCompletions = self.mWriteCharacteristicCompletions.removeValue(forKey: uuidArgs)
        if writeCharacteristicCompletions != nil {
            let completions = writeCharacteristicCompletions!.values
            for completion in completions {
                completion(.failure(errorNotNil))
            }
        }
        let notifyCharacteristicCompletions = self.mSetCharacteristicNotifyStateCompletions.removeValue(forKey: uuidArgs)
        if notifyCharacteristicCompletions != nil {
            let completions = notifyCharacteristicCompletions!.values
            for completioin in completions {
                completioin(.failure(errorNotNil))
            }
        }
        let readDescriptorCompletions = self.mReadDescriptorCompletions.removeValue(forKey: uuidArgs)
        if readDescriptorCompletions != nil {
            let completions = readDescriptorCompletions!.values
            for completioin in completions {
                completioin(.failure(errorNotNil))
            }
        }
        let writeDescriptorCompletions = self.mWriteDescriptorCompletions.removeValue(forKey: uuidArgs)
        if writeDescriptorCompletions != nil {
            let completions = writeDescriptorCompletions!.values
            for completion in completions {
                completion(.failure(errorNotNil))
            }
        }
        let stateArgs = MyConnectionStateArgs.disconnected
        mAPI.onConnectionStateChanged(peripheralArgs: peripheralArgs, stateArgs: stateArgs) { _ in }
        guard let completion = mDisconnectCompletions.removeValue(forKey: uuidArgs) else {
            return
        }
        if error == nil {
            completion(.success(()))
        } else {
            completion(.failure(error!))
        }
    }

    func didReadRSSI(peripheral: CBPeripheral, rssi: NSNumber, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        guard let completion = mReadRSSICompletions.removeValue(forKey: uuidArgs) else {
            return
        }
        if error == nil {
            let rssiArgs = rssi.int64Value
            completion(.success((rssiArgs)))
        } else {
            completion(.failure(error!))
        }
    }

    func didDiscoverServices(peripheral: CBPeripheral, error: Error?) {
        NSLog("[BLE-Bitchat] ====== DID DISCOVER SERVICES ======")
        let uuidArgs = peripheral.identifier.toArgs()
        NSLog("[BLE-Bitchat] didDiscoverServices callback for: \(uuidArgs)")
        NSLog("[BLE-Bitchat] Peripheral: \(peripheral.name ?? "unknown"), state: \(peripheralStateDescription(peripheral.state))")
        if let error = error {
            NSLog("[BLE-Bitchat] ERROR in didDiscoverServices: \(error.localizedDescription)")
        }
        guard let completion = mDiscoverServicesCompletions.removeValue(forKey: uuidArgs) else {
            NSLog("[BLE-Bitchat] WARNING: No completion handler found for \(uuidArgs) (unexpected callback)")
            return
        }
        if error == nil {
            let services = peripheral.services ?? []
            NSLog("[BLE-Bitchat] Found \(services.count) services")
            var servicesArgs = [MyGATTServiceArgs]()
            for service in services {
                NSLog("[BLE-Bitchat]   Service: \(service.uuid.uuidString)")
                let serviceArgs = service.toArgs()
                self.mServices[uuidArgs, default: [:]][serviceArgs.hashCodeArgs] = service
                servicesArgs.append(serviceArgs)
            }
            NSLog("[BLE-Bitchat] Calling completion with \(servicesArgs.count) services (dispatching to main thread)")
            // CRITICAL: Flutter platform channel requires replies on main thread
            DispatchQueue.main.async {
                completion(.success(servicesArgs))
            }
        } else {
            NSLog("[BLE-Bitchat] Calling completion with error: \(error!.localizedDescription)")
            // CRITICAL: Flutter platform channel requires replies on main thread
            DispatchQueue.main.async {
                completion(.failure(error!))
            }
        }
    }

    func didDiscoverIncludedServices(peripheral: CBPeripheral, service: CBService, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        let hashCodeArgs = service.hash.toInt64()
        guard let completion = mDiscoverIncludedServicesCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            return
        }
        if error == nil {
            let includedServices = service.includedServices ?? []
            var includedServicesArgs = [MyGATTServiceArgs]()
            for includedService in includedServices {
                let includedServiceArgs = includedService.toArgs()
                self.mServices[uuidArgs, default: [:]][includedServiceArgs.hashCodeArgs] = includedService
                includedServicesArgs.append(includedServiceArgs)
            }
            completion(.success(includedServicesArgs))
        } else {
            completion(.failure(error!))
        }
    }

    func didDiscoverCharacteristics(peripheral: CBPeripheral, service: CBService, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        let hashCodeArgs = service.hash.toInt64()
        guard let completion = mDiscoverCharacteristicsCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            return
        }
        if error == nil {
            let characteristics = service.characteristics ?? []
            var characteristicsArgs = [MyGATTCharacteristicArgs]()
            for characteristic in characteristics {
                let characteristicArgs = characteristic.toArgs()
                self.mCharacteristics[uuidArgs, default: [:]][characteristicArgs.hashCodeArgs] = characteristic
                characteristicsArgs.append(characteristicArgs)
            }
            completion(.success(characteristicsArgs))
        } else {
            completion(.failure(error!))
        }
    }

    func didDiscoverDescriptors(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        let hashCodeArgs = characteristic.hash.toInt64()
        guard let completion = mDiscoverDescriptorsCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            return
        }
        if error == nil {
            let descriptors = characteristic.descriptors ?? []
            var descriptorsArgs = [MyGATTDescriptorArgs]()
            for descriptor in descriptors {
                let descriptorArgs = descriptor.toArgs()
                self.mDescriptors[uuidArgs, default: [:]][descriptorArgs.hashCodeArgs] = descriptor
                descriptorsArgs.append(descriptorArgs)
            }
            completion(.success(descriptorsArgs))
        } else {
            completion(.failure(error!))
        }
    }

    func didUpdateCharacteristicValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        let peripheralArgs = peripheral.toArgs()
        let uuidArgs = peripheralArgs.uuidArgs
        let characteristicArgs = characteristic.toArgs()
        let hashCodeArgs = characteristicArgs.hashCodeArgs
        let value = characteristic.value ?? Data()
        let valueArgs = FlutterStandardTypedData(bytes: value)
        guard let completion = mReadCharacteristicCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            mAPI.onCharacteristicNotified(peripheralArgs: peripheralArgs, characteristicArgs: characteristicArgs, valueArgs: valueArgs) { _ in }
            return
        }
        if error == nil {
            completion(.success(valueArgs))
        } else {
            completion(.failure(error!))
        }
    }

    func didWriteCharacteristicValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        let hashCodeArgs = characteristic.hash.toInt64()
        guard let completion = mWriteCharacteristicCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            return
        }
        if error == nil {
            completion(.success(()))
        } else {
            completion(.failure(error!))
        }
    }

    func didUpdateCharacteristicNotificationState(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        let hashCodeArgs = characteristic.hash.toInt64()
        guard let completion = mSetCharacteristicNotifyStateCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            return
        }
        if error == nil {
            completion(.success(()))
        } else {
            completion(.failure(error!))
        }
    }

    func didUpdateDescriptorValue(peripheral: CBPeripheral, descriptor: CBDescriptor, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        let hashCodeArgs = descriptor.hash.toInt64()
        guard let completion = mReadDescriptorCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            return
        }
        if error == nil {
            let valueArgs: FlutterStandardTypedData
            switch descriptor.value {
            case let bytes as Data:
                valueArgs = FlutterStandardTypedData(bytes: bytes)
            case let value as String:
                let bytes = value.data(using: .utf8) ?? Data()
                valueArgs = FlutterStandardTypedData(bytes: bytes)
            case let value as UInt16:
                let bytes = value.data
                valueArgs = FlutterStandardTypedData(bytes: bytes)
            case let value as NSNumber:
                let bytes = withUnsafeBytes(of: value) { elements in Data(elements) }
                valueArgs = FlutterStandardTypedData(bytes: bytes)
            default:
                valueArgs = FlutterStandardTypedData()
            }
            completion(.success((valueArgs)))
        } else {
            completion(.failure(error!))
        }
    }

    func didWriteDescriptorValue(peripheral: CBPeripheral, descriptor: CBDescriptor, error: Error?) {
        let uuidArgs = peripheral.identifier.toArgs()
        let hashCodeArgs = descriptor.hash.toInt64()
        guard let completion = mWriteDescriptorCompletions[uuidArgs]?.removeValue(forKey: hashCodeArgs) else {
            return
        }
        if error == nil {
            completion(.success(()))
        } else {
            completion(.failure(error!))
        }
    }

    private func retrievePeripheral(uuidArgs: String) throws -> CBPeripheral {
        guard let peripheral = mPeripherals[uuidArgs] else {
            throw MyError.illegalArgument
        }
        return peripheral
    }

    private func retrieveService(uuidArgs: String, hashCodeArgs: Int64) throws -> CBService {
        guard let services = self.mServices[uuidArgs] else {
            throw MyError.illegalArgument
        }
        guard let service = services[hashCodeArgs] else {
            throw MyError.illegalArgument
        }
        return service
    }

    private func retrieveCharacteristic(uuidArgs: String, hashCodeArgs: Int64) throws -> CBCharacteristic {
        guard let characteristics = self.mCharacteristics[uuidArgs] else {
            throw MyError.illegalArgument
        }
        guard let characteristic = characteristics[hashCodeArgs] else {
            throw MyError.illegalArgument
        }
        return characteristic
    }

    private func retrieveDescriptor(uuidArgs: String, hashCodeArgs: Int64) throws -> CBDescriptor {
        guard let descriptors = self.mDescriptors[uuidArgs] else {
            throw MyError.illegalArgument
        }
        guard let descriptor = descriptors[hashCodeArgs] else {
            throw MyError.illegalArgument
        }
        return descriptor
    }
}
