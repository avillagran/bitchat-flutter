import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import 'package:bitchat/core/constants.dart';

/// Tag for debug logging throughout BleManager.
const String _tag = '[BleManager]';

/// Mesh service UUID parsed as bluetooth_low_energy UUID type.
final UUID meshServiceUUID = UUID.fromString(AppConstants.meshServiceUuid);

/// Mesh characteristic UUID parsed as bluetooth_low_energy UUID type.
final UUID meshCharacteristicUUID =
    UUID.fromString(AppConstants.meshCharacteristicUuid);

/// Mesh CCCD descriptor UUID (Client Characteristic Configuration Descriptor).
final UUID meshDescriptorUUID =
    UUID.fromString(AppConstants.meshDescriptorUuid);

/// BLE Manager - Singleton that provides unified access to both Central and
/// Peripheral BLE roles using the bluetooth_low_energy package.
///
/// This class abstracts platform differences and provides:
/// - Unified state management for the Bluetooth adapter
/// - Central role for scanning and connecting to peripherals
/// - Peripheral role for GATT server and advertising
/// - Platform capability detection (Linux doesn't support Peripheral)
///
/// Usage:
/// ```dart
/// final manager = BleManager.instance;
/// await manager.initialize();
///
/// // Check capabilities
/// if (manager.supportsCentral) {
///   manager.central.startDiscovery();
/// }
///
/// if (manager.supportsPeripheral) {
///   await manager.peripheral.addService(gattService);
///   await manager.peripheral.startAdvertising(advertisement);
/// }
/// ```
class BleManager {
  /// Singleton instance of BleManager.
  static final BleManager instance = BleManager._();

  /// Private constructor for singleton pattern.
  BleManager._();

  /// Internal reference to CentralManager from bluetooth_low_energy.
  CentralManager? _centralManager;

  /// Internal reference to PeripheralManager from bluetooth_low_energy.
  PeripheralManager? _peripheralManager;

  /// Flag indicating if initialization has been completed.
  bool _initialized = false;

  /// Cached platform capability for Central role.
  bool _supportsCentral = false;

  /// Cached platform capability for Peripheral role.
  bool _supportsPeripheral = false;

  /// Stream controller for unified Bluetooth state across both managers.
  final StreamController<BluetoothLowEnergyState> _stateController =
      StreamController<BluetoothLowEnergyState>.broadcast();

  /// Subscription to central manager state changes.
  StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>?
      _centralStateSubscription;

  /// Subscription to peripheral manager state changes.
  StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>?
      _peripheralStateSubscription;

  /// Last known Bluetooth state.
  BluetoothLowEnergyState _lastState = BluetoothLowEnergyState.unknown;

  // ---------------------------------------------------------------------------
  // Public API - Getters
  // ---------------------------------------------------------------------------

  /// Returns the CentralManager instance for scanning and connecting.
  ///
  /// Throws [StateError] if BleManager has not been initialized or if
  /// the platform does not support Central role.
  CentralManager get central {
    if (!_initialized) {
      throw StateError(
          '$_tag BleManager not initialized. Call initialize() first.');
    }
    if (_centralManager == null) {
      throw StateError('$_tag CentralManager not available on this platform.');
    }
    return _centralManager!;
  }

  /// Returns the PeripheralManager instance for GATT server and advertising.
  ///
  /// Throws [StateError] if BleManager has not been initialized or if
  /// the platform does not support Peripheral role (e.g., Linux).
  PeripheralManager get peripheral {
    if (!_initialized) {
      throw StateError(
          '$_tag BleManager not initialized. Call initialize() first.');
    }
    if (_peripheralManager == null) {
      throw StateError(
          '$_tag PeripheralManager not available on this platform (Linux limitation).');
    }
    return _peripheralManager!;
  }

  /// Stream of Bluetooth adapter state changes.
  ///
  /// Emits state from either CentralManager or PeripheralManager,
  /// prioritizing the most restrictive state (e.g., if either is off,
  /// the combined state is off).
  Stream<BluetoothLowEnergyState> get stateStream => _stateController.stream;

  /// Returns the last known Bluetooth adapter state.
  BluetoothLowEnergyState get state => _lastState;

  /// Whether Bluetooth is currently enabled and ready.
  Future<bool> get isBluetoothEnabled async {
    if (!_initialized) {
      return false;
    }

    // Check central manager state if available (synchronous getter)
    if (_centralManager != null) {
      final currentState = _centralManager!.state;
      return currentState == BluetoothLowEnergyState.poweredOn;
    }

    // Fallback to peripheral manager state
    if (_peripheralManager != null) {
      final currentState = _peripheralManager!.state;
      return currentState == BluetoothLowEnergyState.poweredOn;
    }

    return false;
  }

  /// Whether this platform supports Central role (scanning/connecting).
  ///
  /// Currently true for Android, iOS, macOS, Windows, and Linux.
  bool get supportsCentral => _supportsCentral;

  /// Whether this platform supports Peripheral role (GATT server/advertising).
  ///
  /// True for Android, iOS, macOS, Windows.
  /// False for Linux (bluez limitation).
  bool get supportsPeripheral => _supportsPeripheral;

  /// Whether BleManager has been initialized.
  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes the BLE managers for the current platform.
  ///
  /// This method:
  /// - Detects platform capabilities
  /// - Creates CentralManager and PeripheralManager instances
  /// - Sets up state monitoring
  ///
  /// Returns true if initialization succeeded.
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<bool> initialize() async {
    debugPrint('$_tag ****************************************');
    debugPrint('$_tag * BLE MANAGER INITIALIZE() CALLED     *');
    debugPrint('$_tag ****************************************');

    if (_initialized) {
      debugPrint('$_tag Already initialized, returning true');
      return true;
    }

    debugPrint('$_tag Starting BLE initialization...');
    debugPrint('$_tag Platform: ${_getPlatformName()}');

    try {
      // Detect platform capabilities
      debugPrint('$_tag Step 1: Detecting platform capabilities...');
      _detectPlatformCapabilities();

      // Initialize Central Manager (available on all platforms)
      if (_supportsCentral) {
        debugPrint('$_tag Step 2: Initializing Central Manager...');
        _initializeCentralManager();
      } else {
        debugPrint('$_tag Step 2: SKIPPED - Central not supported');
      }

      // Initialize Peripheral Manager (not available on Linux)
      if (_supportsPeripheral) {
        debugPrint('$_tag Step 3: Initializing Peripheral Manager...');
        _initializePeripheralManager();
      } else {
        debugPrint('$_tag Step 3: SKIPPED - Peripheral not supported');
      }

      _initialized = true;
      debugPrint('$_tag ****************************************');
      debugPrint('$_tag * BLE INITIALIZATION COMPLETE         *');
      debugPrint('$_tag ****************************************');
      debugPrint('$_tag Summary:');
      debugPrint('$_tag   Central support: $_supportsCentral');
      debugPrint('$_tag   Peripheral support: $_supportsPeripheral');
      debugPrint('$_tag   Last known state: $_lastState');

      return true;
    } catch (e, stackTrace) {
      debugPrint('$_tag ****************************************');
      debugPrint('$_tag * BLE INITIALIZATION FAILED!          *');
      debugPrint('$_tag ****************************************');
      debugPrint('$_tag Error: $e');
      debugPrint('$_tag Stack trace: $stackTrace');
      _initialized = false;
      return false;
    }
  }

  /// Detects what BLE capabilities are available on the current platform.
  void _detectPlatformCapabilities() {
    // Central role is supported on all platforms
    _supportsCentral = true;

    // Peripheral role is NOT supported on Linux due to bluez limitations
    if (Platform.isLinux) {
      _supportsPeripheral = false;
      debugPrint('$_tag Linux detected - Peripheral role not supported');
    } else if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows) {
      _supportsPeripheral = true;
    } else {
      // Unknown platform - assume no peripheral support
      _supportsPeripheral = false;
      debugPrint('$_tag Unknown platform - Peripheral role disabled');
    }
  }

  /// Initializes the CentralManager and subscribes to state changes.
  void _initializeCentralManager() {
    debugPrint('$_tag ====== CENTRAL MANAGER INIT START ======');
    debugPrint('$_tag Creating CentralManager() instance...');

    _centralManager = CentralManager();

    debugPrint('$_tag CentralManager created, setting up state listener...');

    // Subscribe to state changes
    _centralStateSubscription = _centralManager!.stateChanged.listen(
      (eventArgs) {
        debugPrint('$_tag *** Central state changed callback: ${eventArgs.state}');
        debugPrint('$_tag State description: ${eventArgs.state.description}');
        _handleStateChange(eventArgs.state);
      },
      onError: (e, stack) {
        debugPrint('$_tag Central state stream error: $e');
        debugPrint('$_tag Stack: $stack');
      },
    );

    // Get initial state (synchronous getter)
    debugPrint('$_tag Getting initial central state...');
    final initialState = _centralManager!.state;
    debugPrint('$_tag Central initial state: $initialState (${initialState.description})');
    _handleStateChange(initialState);
    debugPrint('$_tag ====== CENTRAL MANAGER INIT COMPLETE ======');
  }

  /// Initializes the PeripheralManager and subscribes to state changes.
  void _initializePeripheralManager() {
    debugPrint('$_tag ====== PERIPHERAL MANAGER INIT START ======');
    debugPrint('$_tag Creating PeripheralManager() instance...');

    _peripheralManager = PeripheralManager();

    debugPrint('$_tag PeripheralManager created, setting up state listener...');

    // Subscribe to state changes
    _peripheralStateSubscription = _peripheralManager!.stateChanged.listen(
      (eventArgs) {
        debugPrint('$_tag *** Peripheral state changed callback: ${eventArgs.state}');
        debugPrint('$_tag State description: ${eventArgs.state.description}');
        _handleStateChange(eventArgs.state);
      },
      onError: (e, stack) {
        debugPrint('$_tag Peripheral state stream error: $e');
        debugPrint('$_tag Stack: $stack');
      },
    );

    // Get initial state (synchronous getter)
    debugPrint('$_tag Getting initial peripheral state...');
    final initialState = _peripheralManager!.state;
    debugPrint('$_tag Peripheral initial state: $initialState (${initialState.description})');
    debugPrint('$_tag ====== PERIPHERAL MANAGER INIT COMPLETE ======');
  }

  /// Handles state changes from either Central or Peripheral manager.
  ///
  /// Emits the state to the unified stream if it differs from the last state.
  void _handleStateChange(BluetoothLowEnergyState newState) {
    if (newState != _lastState) {
      _lastState = newState;
      _stateController.add(newState);
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Disposes of all resources and resets the manager.
  ///
  /// After calling dispose(), you must call initialize() again before using
  /// the manager.
  Future<void> dispose() async {
    debugPrint('$_tag Disposing BLE managers...');

    // Cancel state subscriptions
    await _centralStateSubscription?.cancel();
    _centralStateSubscription = null;

    await _peripheralStateSubscription?.cancel();
    _peripheralStateSubscription = null;

    // Clear manager references
    _centralManager = null;
    _peripheralManager = null;

    // Reset state
    _initialized = false;
    _supportsCentral = false;
    _supportsPeripheral = false;
    _lastState = BluetoothLowEnergyState.unknown;

    debugPrint('$_tag Disposed');
  }

  // ---------------------------------------------------------------------------
  // Utility Methods
  // ---------------------------------------------------------------------------

  /// Returns debug information about the current manager state.
  Map<String, dynamic> getDebugInfo() {
    return {
      'initialized': _initialized,
      'supportsCentral': _supportsCentral,
      'supportsPeripheral': _supportsPeripheral,
      'lastState': _lastState.toString(),
      'centralManagerAvailable': _centralManager != null,
      'peripheralManagerAvailable': _peripheralManager != null,
      'platform': _getPlatformName(),
      'meshServiceUUID': AppConstants.meshServiceUuid,
      'meshCharacteristicUUID': AppConstants.meshCharacteristicUuid,
    };
  }

  /// Returns the current platform name for debugging.
  String _getPlatformName() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}

/// Extension on BluetoothLowEnergyState for convenience methods.
extension BluetoothLowEnergyStateExtension on BluetoothLowEnergyState {
  /// Whether the adapter is powered on and ready.
  bool get isReady => this == BluetoothLowEnergyState.poweredOn;

  /// Whether the adapter is in a non-ready state.
  bool get isNotReady => this != BluetoothLowEnergyState.poweredOn;

  /// Human-readable description of the state.
  String get description {
    switch (this) {
      case BluetoothLowEnergyState.unknown:
        return 'Unknown';
      case BluetoothLowEnergyState.unsupported:
        return 'Unsupported';
      case BluetoothLowEnergyState.unauthorized:
        return 'Unauthorized';
      case BluetoothLowEnergyState.poweredOff:
        return 'Powered Off';
      case BluetoothLowEnergyState.poweredOn:
        return 'Powered On';
    }
  }
}

/// BleCentralWrapper - Higher-level wrapper for CentralManager with
/// convenience methods for mesh-specific operations.
///
/// Provides:
/// - Mesh service filtering for discovery
/// - Connection management with timeout handling
/// - MTU negotiation helpers
class BleCentralWrapper {
  static const String _wrapperTag = '[BleCentralWrapper]';

  final CentralManager _manager;

  /// Creates a wrapper around the given CentralManager.
  BleCentralWrapper(this._manager);

  /// The underlying CentralManager instance.
  CentralManager get manager => _manager;

  /// Starts discovery for devices advertising the mesh service.
  ///
  /// This filters scan results to only include devices that advertise
  /// our mesh service UUID.
  Future<void> startMeshDiscovery() async {
    debugPrint('$_wrapperTag Starting mesh service discovery...');
    await _manager.startDiscovery(serviceUUIDs: [meshServiceUUID]);
  }

  /// Stops the current discovery session.
  Future<void> stopDiscovery() async {
    debugPrint('$_wrapperTag Stopping discovery');
    await _manager.stopDiscovery();
  }

  /// Stream of discovered peripherals.
  ///
  /// Filters to only include devices advertising the mesh service UUID.
  Stream<DiscoveredEventArgs> get meshDeviceDiscovered {
    return _manager.discovered.where((event) {
      final serviceUUIDs = event.advertisement.serviceUUIDs;
      return serviceUUIDs.contains(meshServiceUUID);
    });
  }

  /// Stream of all discovered peripherals (unfiltered).
  Stream<DiscoveredEventArgs> get allDevicesDiscovered => _manager.discovered;

  /// Connects to a peripheral with timeout handling.
  ///
  /// Returns the connected peripheral or throws on timeout/failure.
  Future<void> connectWithTimeout(
    Peripheral peripheral, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    debugPrint('$_wrapperTag Connecting to ${peripheral.uuid}...');

    await _manager.connect(peripheral).timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException(
            '$_wrapperTag Connection to ${peripheral.uuid} timed out after ${timeout.inSeconds}s');
      },
    );

    debugPrint('$_wrapperTag Connected to ${peripheral.uuid}');
  }

  /// Disconnects from a peripheral.
  Future<void> disconnect(Peripheral peripheral) async {
    debugPrint('$_wrapperTag Disconnecting from ${peripheral.uuid}');
    await _manager.disconnect(peripheral);
  }

  /// Discovers GATT services on a connected peripheral.
  Future<List<GATTService>> discoverGATT(Peripheral peripheral) async {
    debugPrint('$_wrapperTag Discovering GATT for ${peripheral.uuid}...');
    final services = await _manager.discoverGATT(peripheral);
    debugPrint('$_wrapperTag Found ${services.length} services');
    return services;
  }

  /// Finds the mesh service on a connected peripheral.
  ///
  /// Returns the mesh GATTService or null if not found.
  Future<GATTService?> findMeshService(Peripheral peripheral) async {
    final services = await discoverGATT(peripheral);

    for (final service in services) {
      if (service.uuid == meshServiceUUID) {
        debugPrint('$_wrapperTag Found mesh service on ${peripheral.uuid}');
        return service;
      }
    }

    debugPrint('$_wrapperTag Mesh service not found on ${peripheral.uuid}');
    return null;
  }

  /// Finds the mesh characteristic within a service.
  ///
  /// Returns the mesh GATTCharacteristic or null if not found.
  GATTCharacteristic? findMeshCharacteristic(GATTService service) {
    for (final char in service.characteristics) {
      if (char.uuid == meshCharacteristicUUID) {
        debugPrint('$_wrapperTag Found mesh characteristic');
        return char;
      }
    }

    debugPrint('$_wrapperTag Mesh characteristic not found in service');
    return null;
  }

  /// Reads the maximum write length for a peripheral.
  Future<int> getMaximumWriteLength(
    Peripheral peripheral, {
    GATTCharacteristicWriteType type = GATTCharacteristicWriteType.withResponse,
  }) async {
    final length = await _manager.getMaximumWriteLength(
      peripheral,
      type: type,
    );
    debugPrint('$_wrapperTag Max write length for ${peripheral.uuid}: $length');
    return length;
  }

  /// Stream of connection state changes.
  Stream<PeripheralConnectionStateChangedEventArgs>
      get connectionStateChanged => _manager.connectionStateChanged;

  /// Stream of characteristic value changes (notifications/indications).
  Stream<GATTCharacteristicNotifiedEventArgs> get characteristicNotified =>
      _manager.characteristicNotified;

  /// Enables notifications for a characteristic.
  Future<void> enableNotifications(
    Peripheral peripheral,
    GATTCharacteristic characteristic,
  ) async {
    debugPrint(
        '$_wrapperTag Enabling notifications for ${characteristic.uuid}');
    await _manager.setCharacteristicNotifyState(
      peripheral,
      characteristic,
      state: true,
    );
  }

  /// Disables notifications for a characteristic.
  Future<void> disableNotifications(
    Peripheral peripheral,
    GATTCharacteristic characteristic,
  ) async {
    debugPrint(
        '$_wrapperTag Disabling notifications for ${characteristic.uuid}');
    await _manager.setCharacteristicNotifyState(
      peripheral,
      characteristic,
      state: false,
    );
  }

  /// Writes data to a characteristic.
  Future<void> writeCharacteristic(
    Peripheral peripheral,
    GATTCharacteristic characteristic,
    Uint8List value, {
    GATTCharacteristicWriteType type =
        GATTCharacteristicWriteType.withoutResponse,
  }) async {
    await _manager.writeCharacteristic(
      peripheral,
      characteristic,
      value: value,
      type: type,
    );
  }

  /// Reads data from a characteristic.
  Future<Uint8List> readCharacteristic(
    Peripheral peripheral,
    GATTCharacteristic characteristic,
  ) async {
    return await _manager.readCharacteristic(peripheral, characteristic);
  }
}

/// BlePeripheralWrapper - Higher-level wrapper for PeripheralManager with
/// convenience methods for mesh-specific GATT server operations.
///
/// Provides:
/// - Mesh GATT service setup
/// - Advertising configuration for mesh discovery
/// - Write request handling
class BlePeripheralWrapper {
  static const String _wrapperTag = '[BlePeripheralWrapper]';

  final PeripheralManager _manager;

  /// Creates a wrapper around the given PeripheralManager.
  BlePeripheralWrapper(this._manager);

  /// The underlying PeripheralManager instance.
  PeripheralManager get manager => _manager;

  /// Creates and adds the mesh GATT service with characteristic.
  ///
  /// The characteristic supports:
  /// - Read (for handshake/identity)
  /// - Write (for receiving mesh packets)
  /// - Notify (for sending mesh packets)
  ///
  /// Returns the created mesh characteristic for use with notifications.
  Future<GATTCharacteristic> setupMeshService() async {
    debugPrint('$_wrapperTag Setting up mesh GATT service...');

    // Create the mesh characteristic with read, write, and notify properties
    // Using the mutable factory which requires permissions
    final meshCharacteristic = GATTCharacteristic.mutable(
      uuid: meshCharacteristicUUID,
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
        GATTCharacteristicProperty.notify,
      ],
      permissions: [
        GATTCharacteristicPermission.read,
        GATTCharacteristicPermission.write,
      ],
      descriptors: [
        // CCCD for notifications - immutable with initial value (notifications disabled)
        GATTDescriptor.immutable(
          uuid: meshDescriptorUUID,
          value: Uint8List.fromList([0x00, 0x00]),
        ),
      ],
    );

    // Create the mesh service containing the characteristic
    final meshService = GATTService(
      uuid: meshServiceUUID,
      isPrimary: true,
      includedServices: [],
      characteristics: [meshCharacteristic],
    );

    // Remove all existing services first (in case of restart)
    try {
      await _manager.removeAllServices();
    } catch (e) {
      // Ignore errors if no services existed
      debugPrint('$_wrapperTag Note: removeAllServices returned: $e');
    }

    // Add the service
    await _manager.addService(meshService);
    debugPrint('$_wrapperTag Mesh service added successfully');
    debugPrint('$_wrapperTag   Service UUID: ${AppConstants.meshServiceUuid}');
    debugPrint(
        '$_wrapperTag   Characteristic UUID: ${AppConstants.meshCharacteristicUuid}');

    return meshCharacteristic;
  }

  /// Starts advertising the mesh service for discovery by other nodes.
  ///
  /// The advertisement includes the mesh service UUID so other devices
  /// can filter their scans.
  Future<void> startMeshAdvertising({String? localName}) async {
    debugPrint('$_wrapperTag Starting mesh advertising...');

    final advertisement = Advertisement(
      name: localName ?? 'bitchat',
      serviceUUIDs: [meshServiceUUID],
    );

    await _manager.startAdvertising(advertisement);
    debugPrint('$_wrapperTag Advertising started');
  }

  /// Stops advertising.
  Future<void> stopAdvertising() async {
    debugPrint('$_wrapperTag Stopping advertising');
    await _manager.stopAdvertising();
  }

  /// Sends a notification to a connected central.
  Future<void> notifyCharacteristic(
    Central central,
    GATTCharacteristic characteristic,
    Uint8List value,
  ) async {
    await _manager.notifyCharacteristic(
      central,
      characteristic,
      value: value,
    );
  }

  /// Gets the maximum notification length for a central.
  Future<int> getMaximumNotifyLength(Central central) async {
    return await _manager.getMaximumNotifyLength(central);
  }

  /// Responds to a read request with data.
  Future<void> respondReadRequest(
    GATTReadRequest request,
    Uint8List value,
  ) async {
    await _manager.respondReadRequestWithValue(request, value: value);
  }

  /// Responds to a read request with an error.
  Future<void> respondReadRequestError(
    GATTReadRequest request,
    GATTError error,
  ) async {
    await _manager.respondReadRequestWithError(request, error: error);
  }

  /// Responds to a write request (acknowledges the write).
  Future<void> respondWriteRequest(GATTWriteRequest request) async {
    await _manager.respondWriteRequest(request);
  }

  /// Responds to a write request with an error.
  Future<void> respondWriteRequestError(
    GATTWriteRequest request,
    GATTError error,
  ) async {
    await _manager.respondWriteRequestWithError(request, error: error);
  }

  /// Stream of write requests from connected centrals.
  Stream<GATTCharacteristicWriteRequestedEventArgs>
      get characteristicWriteRequested => _manager.characteristicWriteRequested;

  /// Stream of read requests from connected centrals.
  Stream<GATTCharacteristicReadRequestedEventArgs>
      get characteristicReadRequested => _manager.characteristicReadRequested;

  /// Stream of notification state changes (when a central subscribes/unsubscribes).
  Stream<GATTCharacteristicNotifyStateChangedEventArgs>
      get characteristicNotifyStateChanged =>
          _manager.characteristicNotifyStateChanged;
}
