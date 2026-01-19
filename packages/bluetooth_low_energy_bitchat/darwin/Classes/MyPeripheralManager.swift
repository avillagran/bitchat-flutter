//
//  MyPeripheralManager.swift
//  bluetooth_low_energy_darwin
//
//  Created by 闫守旺 on 2023/10/7.
//
//  Modified for bluetooth_low_energy_bitchat: lazy CBPeripheralManager initialization
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

class MyPeripheralManager: MyPeripheralManagerHostAPI {
    private let mAPI: MyPeripheralManagerFlutterAPI
    // LAZY INIT: CBPeripheralManager is now optional and created on first use
    private var mPeripheralManager: CBPeripheralManager?

    private lazy var mPeripheralManagerDelegate = MyPeripheralManagerDelegate(peripheralManager: self)

    private var mServicesArgs: [Int: MyMutableGATTServiceArgs]
    private var mCharacteristicsArgs: [Int: MyMutableGATTCharacteristicArgs]
    private var mDescriptorsArgs: [Int: MyMutableGATTDescriptorArgs]

    private var mCentrals: [String: CBCentral]
    private var mServices: [Int64: CBMutableService]
    private var mCharacteristics: [Int64: CBMutableCharacteristic]
    private var mDescriptors: [Int64: CBMutableDescriptor]
    private var mRequests: [Int64: CBATTRequest]

    private var mAddServiceCompletion: ((Result<Void, Error>) -> Void)?
    private var mStartAdvertisingCompletion: ((Result<Void, Error>) -> Void)?

    init(messenger: FlutterBinaryMessenger) {
        mAPI = MyPeripheralManagerFlutterAPI(binaryMessenger: messenger)
        // LAZY INIT: DO NOT create CBPeripheralManager here - it triggers TCC immediately
        // mPeripheralManager will be created in getPeripheralManager() on first use

        mServicesArgs = [:]
        mCharacteristicsArgs = [:]
        mDescriptorsArgs = [:]

        mCentrals = [:]
        mServices = [:]
        mCharacteristics = [:]
        mDescriptors = [:]
        mRequests = [:]

        mAddServiceCompletion = nil
        mStartAdvertisingCompletion = nil
    }

    // LAZY INIT: Get or create CBPeripheralManager on demand
    // IMPORTANT: Must pass delegate at creation time to receive initial peripheralManagerDidUpdateState
    private func getPeripheralManager() -> CBPeripheralManager {
        if mPeripheralManager == nil {
            NSLog("[BLE-Bitchat-Peripheral] Creating CBPeripheralManager with delegate...")
            mPeripheralManager = CBPeripheralManager(delegate: mPeripheralManagerDelegate, queue: nil)
            NSLog("[BLE-Bitchat-Peripheral] CBPeripheralManager created, state: \(mPeripheralManager!.state.rawValue) (\(stateDescription(mPeripheralManager!.state)))")
        }
        return mPeripheralManager!
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

    func initialize() throws {
        NSLog("[BLE-Bitchat-Peripheral] ====== PERIPHERAL INITIALIZE START ======")

        // LAZY INIT: CBPeripheralManager is created here when Dart calls initialize()
        let peripheralManager = getPeripheralManager()
        NSLog("[BLE-Bitchat-Peripheral] After getPeripheralManager, state: \(peripheralManager.state.rawValue) (\(stateDescription(peripheralManager.state)))")

        if(peripheralManager.isAdvertising) {
            NSLog("[BLE-Bitchat-Peripheral] Stopping existing advertising")
            peripheralManager.stopAdvertising()
        }

        mServicesArgs.removeAll()
        mCharacteristicsArgs.removeAll()
        mDescriptorsArgs.removeAll()

        mCentrals.removeAll()
        mServices.removeAll()
        mCharacteristics.removeAll()
        mDescriptors.removeAll()
        mRequests.removeAll()

        mAddServiceCompletion = nil
        mStartAdvertisingCompletion = nil

        peripheralManager.delegate = mPeripheralManagerDelegate
        NSLog("[BLE-Bitchat-Peripheral] Delegate reassigned")
        NSLog("[BLE-Bitchat-Peripheral] ====== PERIPHERAL INITIALIZE COMPLETE ======")
    }

    func getState() throws -> MyBluetoothLowEnergyStateArgs {
        let state = getPeripheralManager().state
        NSLog("[BLE-Bitchat-Peripheral] getState() called, returning: \(state.rawValue) (\(stateDescription(state)))")
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

    func addService(serviceArgs: MyMutableGATTServiceArgs, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[BLE-Bitchat-Peripheral] ====== ADD SERVICE ======")
        NSLog("[BLE-Bitchat-Peripheral] Adding service UUID: \(serviceArgs.uuidArgs)")
        do {
            let service = try addServiceArgs(serviceArgs)
            NSLog("[BLE-Bitchat-Peripheral] Service created, adding to peripheral manager...")
            getPeripheralManager().add(service)
            mAddServiceCompletion = completion
            NSLog("[BLE-Bitchat-Peripheral] add(service) called, waiting for callback")
        } catch {
            NSLog("[BLE-Bitchat-Peripheral] ERROR: Failed to add service - \(error)")
            completion(.failure(error))
        }
    }

    func removeService(hashCodeArgs: Int64) throws {
        guard let service = mServices[hashCodeArgs] else {
            throw MyError.illegalArgument
        }
        guard let serviceArgs = mServicesArgs[service.hash] else {
            throw MyError.illegalArgument
        }
        getPeripheralManager().remove(service)
        try removeServiceArgs(serviceArgs)
    }

    func removeAllServices() throws {
        getPeripheralManager().removeAllServices()

        mServices.removeAll()
        mCharacteristics.removeAll()
        mDescriptors.removeAll()

        mServicesArgs.removeAll()
        mCharacteristicsArgs.removeAll()
        mDescriptors.removeAll()
    }

    func startAdvertising(advertisementArgs: MyAdvertisementArgs, completion: @escaping (Result<Void, Error>) -> Void) {
        NSLog("[BLE-Bitchat-Peripheral] ====== START ADVERTISING ======")
        let currentState = getPeripheralManager().state
        NSLog("[BLE-Bitchat-Peripheral] Current state: \(currentState.rawValue) (\(stateDescription(currentState)))")
        if currentState != .poweredOn {
            NSLog("[BLE-Bitchat-Peripheral] WARNING: Attempting to advertise while not poweredOn!")
        }
        let advertisement = advertisementArgs.toAdvertisement()
        NSLog("[BLE-Bitchat-Peripheral] Advertisement data: \(advertisement)")
        getPeripheralManager().startAdvertising(advertisement)
        mStartAdvertisingCompletion = completion
        NSLog("[BLE-Bitchat-Peripheral] startAdvertising() called, waiting for callback")
    }

    func stopAdvertising() throws {
        NSLog("[BLE-Bitchat-Peripheral] stopAdvertising() called")
        getPeripheralManager().stopAdvertising()
    }

    func getMaximumNotifyLength(uuidArgs: String) throws -> Int64 {
        guard let central = mCentrals[uuidArgs] else {
            throw MyError.illegalArgument
        }
        let maximumNotifyLength = central.maximumUpdateValueLength
        let maximumNotifyLengthArgs = maximumNotifyLength.toInt64()
        return maximumNotifyLengthArgs
    }

    func respond(hashCodeArgs: Int64, valueArgs: FlutterStandardTypedData?, errorArgs: MyATTErrorArgs) throws {
        guard let request = mRequests.removeValue(forKey: hashCodeArgs) else {
            throw MyError.illegalArgument
        }
        if valueArgs != nil {
            request.value = valueArgs!.data
        }
        let error = errorArgs.toError()
        getPeripheralManager().respond(to: request, withResult: error)
    }

    func updateValue(hashCodeArgs: Int64, valueArgs: FlutterStandardTypedData, uuidsArgs: [String]?) throws -> Bool {
        let centrals = try uuidsArgs?.map { uuidArgs in
            guard let central = self.mCentrals[uuidArgs] else {
                throw MyError.illegalArgument
            }
            return central
        }
        guard let characteristic = mCharacteristics[hashCodeArgs] else {
            throw MyError.illegalArgument
        }
        let value = valueArgs.data
        let updated = getPeripheralManager().updateValue(value, for: characteristic, onSubscribedCentrals: centrals)
        return updated
    }

    func didUpdateState(peripheral: CBPeripheralManager) {
        let state = peripheral.state
        NSLog("[BLE-Bitchat-Peripheral] ====== STATE UPDATE ======")
        NSLog("[BLE-Bitchat-Peripheral] didUpdateState: \(state.rawValue) (\(stateDescription(state)))")
        let stateArgs = state.toArgs()
        NSLog("[BLE-Bitchat-Peripheral] Notifying Dart of peripheral state change...")
        mAPI.onStateChanged(stateArgs: stateArgs) { result in
            switch result {
            case .success:
                NSLog("[BLE-Bitchat-Peripheral] State change notification sent to Dart")
            case .failure(let error):
                NSLog("[BLE-Bitchat-Peripheral] ERROR: Failed to notify Dart - \(error)")
            }
        }
    }

    func didAdd(peripheral: CBPeripheralManager, service: CBService, error: Error?) {
        NSLog("[BLE-Bitchat-Peripheral] ====== SERVICE ADDED CALLBACK ======")
        NSLog("[BLE-Bitchat-Peripheral] Service: \(service.uuid.uuidString)")
        if let error = error {
            NSLog("[BLE-Bitchat-Peripheral] ERROR: \(error.localizedDescription)")
        }
        guard let completion = mAddServiceCompletion else {
            NSLog("[BLE-Bitchat-Peripheral] No completion handler for addService")
            return
        }
        mAddServiceCompletion = nil
        if error == nil {
            NSLog("[BLE-Bitchat-Peripheral] Service added successfully")
            completion(.success(()))
        } else {
            completion(.failure(error!))
        }
    }

    func didStartAdvertising(peripheral: CBPeripheralManager, error: Error?) {
        NSLog("[BLE-Bitchat-Peripheral] ====== ADVERTISING STARTED CALLBACK ======")
        if let error = error {
            NSLog("[BLE-Bitchat-Peripheral] ERROR: \(error.localizedDescription)")
        } else {
            NSLog("[BLE-Bitchat-Peripheral] Advertising started successfully")
        }
        guard let completion = mStartAdvertisingCompletion else {
            NSLog("[BLE-Bitchat-Peripheral] No completion handler for startAdvertising")
            return
        }
        mStartAdvertisingCompletion = nil
        if error == nil {
            completion(.success(()))
        } else {
            completion(.failure(error!))
        }
    }

    func didReceiveRead(peripheral: CBPeripheralManager, request: CBATTRequest) {
        let hashCodeArgs = request.hash.toInt64()
        let central = request.central
        let centralArgs = central.toArgs()
        mCentrals[centralArgs.uuidArgs] = central
        let characteristic = request.characteristic
        guard let characteristicArgs = mCharacteristicsArgs[characteristic.hash] else {
            getPeripheralManager().respond(to: request, withResult: .attributeNotFound)
            return
        }
        let characteristicHashCodeArgs = characteristicArgs.hashCodeArgs
        let value = request.value
        let valueArgs = value == nil ? nil : FlutterStandardTypedData(bytes: value!)
        let offsetArgs = request.offset.toInt64()
        let requestArgs = MyATTRequestArgs(hashCodeArgs: hashCodeArgs, centralArgs: centralArgs, characteristicHashCodeArgs: characteristicHashCodeArgs, valueArgs: valueArgs, offsetArgs: offsetArgs)
        mRequests[hashCodeArgs] = request
        mAPI.didReceiveRead(requestArgs: requestArgs) { _ in }
    }

    func didReceiveWrite(peripheral: CBPeripheralManager, requests: [CBATTRequest]) {
        var requestsArgs = [MyATTRequestArgs]()
        for request in requests {
            let hashCodeArgs = request.hash.toInt64()
            let central = request.central
            let centralArgs = central.toArgs()
            mCentrals[centralArgs.uuidArgs] = central
            let characteristic = request.characteristic
            guard let characteristicArgs = mCharacteristicsArgs[characteristic.hash] else {
                getPeripheralManager().respond(to: request, withResult: .attributeNotFound)
                return
            }
            let characteristicHashCodeArgs = characteristicArgs.hashCodeArgs
            let value = request.value
            let valueArgs = value == nil ? nil : FlutterStandardTypedData(bytes: value!)
            let offsetArgs = request.offset.toInt64()
            let requestArgs = MyATTRequestArgs(hashCodeArgs: hashCodeArgs, centralArgs: centralArgs, characteristicHashCodeArgs: characteristicHashCodeArgs, valueArgs: valueArgs, offsetArgs: offsetArgs)
            requestsArgs.append(requestArgs)
        }
        guard let request = requests.first else {
            return
        }
        guard let requestArgs = requestsArgs.first else {
            return
        }
        self.mRequests[requestArgs.hashCodeArgs] = request
        mAPI.didReceiveWrite(requestsArgs: requestsArgs) { _ in }
    }

    func didSubscribeTo(peripheral: CBPeripheralManager, central: CBCentral, characteristic: CBCharacteristic) {
        let centralArgs = central.toArgs()
        mCentrals[centralArgs.uuidArgs] = central
        let hashCode = characteristic.hash
        guard let characteristicArgs = mCharacteristicsArgs[hashCode] else {
            return
        }
        let hashCodeArgs = characteristicArgs.hashCodeArgs
        let stateArgs = true
        mAPI.onCharacteristicNotifyStateChanged(centralArgs: centralArgs, hashCodeArgs: hashCodeArgs, stateArgs: stateArgs) { _ in }
    }

    func didUnsubscribeFrom(peripheral: CBPeripheralManager, central: CBCentral, characteristic: CBCharacteristic) {
        let centralArgs = central.toArgs()
        mCentrals[centralArgs.uuidArgs] = central
        let hashCode = characteristic.hash
        guard let characteristicArgs = mCharacteristicsArgs[hashCode] else {
            return
        }
        let hashCodeArgs = characteristicArgs.hashCodeArgs
        let stateArgs = false
        mAPI.onCharacteristicNotifyStateChanged(centralArgs: centralArgs, hashCodeArgs: hashCodeArgs, stateArgs: stateArgs) { _ in }
    }

    func isReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
        mAPI.isReady() { _ in }
    }

    private func addServiceArgs(_ serviceArgs: MyMutableGATTServiceArgs) throws -> CBMutableService {
        let service = serviceArgs.toService()
        mServicesArgs[service.hash] = serviceArgs
        mServices[serviceArgs.hashCodeArgs] = service
        var includedServices = [CBService]()
        let includedServicesArgs = serviceArgs.includedServicesArgs
        for args in includedServicesArgs {
            guard let includedServiceArgs = args else {
                throw MyError.illegalArgument
            }
            let includedService = try addServiceArgs(includedServiceArgs)
            self.mServicesArgs[includedService.hash] = includedServiceArgs
            self.mServices[includedServiceArgs.hashCodeArgs] = includedService
            includedServices.append(includedService)
        }
        service.includedServices = includedServices
        var characteristics = [CBMutableCharacteristic]()
        let characteristicsArgs = serviceArgs.characteristicsArgs
        for args in characteristicsArgs {
            guard let characteristicArgs = args else {
                throw MyError.illegalArgument
            }
            let characteristic = characteristicArgs.toCharacteristic()
            self.mCharacteristicsArgs[characteristic.hash] = characteristicArgs
            self.mCharacteristics[characteristicArgs.hashCodeArgs] = characteristic
            characteristics.append(characteristic)
            var descriptors = [CBMutableDescriptor]()
            let descriptorsArgs = characteristicArgs.descriptorsArgs
            for args in descriptorsArgs {
                guard let descriptorArgs = args else {
                    continue
                }
                let descriptor = descriptorArgs.toDescriptor()
                self.mDescriptorsArgs[descriptor.hash] = descriptorArgs
                self.mDescriptors[descriptorArgs.hashCodeArgs] = descriptor
                descriptors.append(descriptor)
            }
            characteristic.descriptors = descriptors
        }
        service.characteristics = characteristics
        return service
    }

    private func removeServiceArgs(_ serviceArgs: MyMutableGATTServiceArgs) throws {
        for args in serviceArgs.includedServicesArgs {
            guard let includedServiceArgs = args else {
                throw MyError.illegalArgument
            }
            try removeServiceArgs(includedServiceArgs)
        }
        for args in serviceArgs.characteristicsArgs {
            guard let characteristicArgs = args else {
                throw MyError.illegalArgument
            }
            for args in characteristicArgs.descriptorsArgs {
                guard let descriptorArgs = args else {
                    throw MyError.illegalArgument
                }
                guard let descriptor = mDescriptors.removeValue(forKey: descriptorArgs.hashCodeArgs) else {
                    throw MyError.illegalArgument
                }
                mDescriptorsArgs.removeValue(forKey: descriptor.hash)
            }
            guard let characteristic = mCharacteristics.removeValue(forKey: characteristicArgs.hashCodeArgs) else {
                throw MyError.illegalArgument
            }
            mCharacteristicsArgs.removeValue(forKey: characteristic.hash)
        }
        guard let service = mServices.removeValue(forKey: serviceArgs.hashCodeArgs) else {
            throw MyError.illegalArgument
        }
        mServicesArgs.removeValue(forKey: service.hash)
    }
}
