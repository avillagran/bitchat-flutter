import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bitchat/core/constants.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/protocol/packet_codec.dart';

/// Delegate interface for GATT client connection events.
/// Used to notify the mesh layer about connection state changes and received packets.
abstract class BluetoothConnectionManagerDelegate {
  /// Called when a peripheral device has been successfully connected and configured.
  void onDeviceConnected(Peripheral device);

  /// Called when a peripheral device has disconnected.
  void onDeviceDisconnected(Peripheral device);

  /// Called when a valid BitchatPacket is received from a connected peripheral.
  void onPacketReceived(BitchatPacket packet, String peerID, Peripheral device);
}

/// GATT Client Manager - handles scanning and connecting to mesh peripherals.
///
/// This manager operates in the BLE Central role, scanning for peripherals that
/// advertise the Bitchat mesh service UUID and managing connections to them.
///
/// Implements robust connection handling with:
/// - Automatic retries (max 3 attempts with 5s delay between retries)
/// - Proper GATT operation sequencing with 200ms delays (matching Android)
/// - MTU negotiation support
/// - Notification-based packet reception
///
/// Matches Android BluetoothGattClientManager patterns for connection reliability.
class GattClientManager {
  static const String _tag = '[GattClientManager]';

  // Connection configuration (matching Android AppConstants.Mesh)
  static const int _maxConnectionRetries = 3;
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static const Duration _operationDelay =
      Duration(milliseconds: 200); // Match Android 200ms delays
  static const Duration _reconnectDelay =
      Duration(seconds: 5); // Match Android CONNECTION_RETRY_DELAY_MS
  static const Duration _cleanupDelay =
      Duration(milliseconds: 500); // Match Android CONNECTION_CLEANUP_DELAY_MS

  /// Delegate to receive connection and packet events.
  BluetoothConnectionManagerDelegate? delegate;

  /// Reference to the CentralManager singleton.
  late final CentralManager _central;

  /// Whether the manager is actively scanning and managing connections.
  bool _isActive = false;

  /// Subscription to discovery events.
  StreamSubscription<DiscoveredEventArgs>? _discoverySubscription;

  /// Subscription to connection state changes.
  StreamSubscription<PeripheralConnectionStateChangedEventArgs>?
      _connectionStateSubscription;

  /// Subscription to characteristic notifications.
  StreamSubscription<GATTCharacteristicNotifiedEventArgs>?
      _notificationSubscription;

  /// Map of connected peripherals by their UUID string.
  final Map<String, Peripheral> _connectedDevices = {};

  /// Map of discovered GATT characteristics by peripheral UUID.
  final Map<String, GATTCharacteristic> _meshCharacteristics = {};

  /// Track connection attempts per device for retry logic.
  final Map<String, int> _connectionAttempts = {};

  /// Set of device UUIDs currently in the process of connecting.
  final Set<String> _connectingDevices = {};

  /// Begins BLE central role, starts scanning for mesh service peripherals.
  ///
  /// Returns true if scanning started successfully, false otherwise.
  Future<bool> start() async {
    if (_isActive) return true;

    try {
      // Initialize the CentralManager using the factory constructor
      _central = CentralManager();

      // Check Bluetooth state
      var state = _central.state;
      if (state != BluetoothLowEnergyState.poweredOn) {
        debugPrint('$_tag Bluetooth is not powered on (state: $state)');

        // Try to authorize if unauthorized (Android and macOS)
        if (state == BluetoothLowEnergyState.unauthorized) {
          debugPrint('$_tag Requesting Bluetooth authorization...');
          try {
            await _central.authorize();
            // Re-check state after authorization
            state = _central.state;
            debugPrint('$_tag State after authorization: $state');
            if (state != BluetoothLowEnergyState.poweredOn) {
              debugPrint('$_tag Authorization did not result in poweredOn state');
              return false;
            }
          } catch (e) {
            debugPrint('$_tag Authorization failed: $e');
            return false;
          }
        } else {
          return false;
        }
      }

      _isActive = true;
      _setupSubscriptions();
      await _startScanning();
      debugPrint('$_tag Started scanning for mesh peers');
      return true;
    } catch (e) {
      debugPrint('$_tag Failed to start: $e');
      return false;
    }
  }

  /// Stops scanning and disconnects all connected devices.
  Future<void> stop() async {
    _isActive = false;

    // Cancel all subscriptions
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    await _notificationSubscription?.cancel();
    _notificationSubscription = null;

    // Stop scanning
    try {
      await _central.stopDiscovery();
    } catch (e) {
      debugPrint('$_tag Error stopping discovery: $e');
    }

    // Disconnect all devices
    for (var entry in _connectedDevices.entries) {
      try {
        await _central.disconnect(entry.value);
        debugPrint('$_tag Disconnected from ${entry.key}');
      } catch (e) {
        debugPrint('$_tag Error disconnecting ${entry.key}: $e');
      }
    }

    _connectedDevices.clear();
    _meshCharacteristics.clear();
    _connectionAttempts.clear();
    _connectingDevices.clear();
    debugPrint('$_tag Stopped');
  }

  /// Sets up all event subscriptions for the CentralManager.
  void _setupSubscriptions() {
    // Listen for connection state changes
    _connectionStateSubscription =
        _central.connectionStateChanged.listen((event) {
      final deviceUuid = event.peripheral.uuid.toString();

      if (event.state == ConnectionState.disconnected) {
        // Device disconnected
        debugPrint('$_tag Device $deviceUuid disconnected');
        final peripheral = _connectedDevices.remove(deviceUuid);
        _meshCharacteristics.remove(deviceUuid);

        if (peripheral != null) {
          delegate?.onDeviceDisconnected(peripheral);
        }

        // Cleanup after delay (matching Android pattern)
        Future.delayed(_cleanupDelay, () {
          _connectingDevices.remove(deviceUuid);
        });
      }
    });

    // Listen for characteristic notifications
    _notificationSubscription = _central.characteristicNotified.listen((event) {
      final value = event.value;

      if (value.isNotEmpty) {
        _onCharacteristicChanged(event.peripheral, Uint8List.fromList(value));
      }
    });
  }

  /// Starts BLE scanning for mesh service peripherals.
  Future<void> _startScanning() async {
    final meshServiceUuid = UUID.fromString(AppConstants.meshServiceUuid);

    // Subscribe to discovery events, filtering by service UUID
    _discoverySubscription = _central.discovered
        .where((event) =>
            event.advertisement.serviceUUIDs.contains(meshServiceUuid))
        .listen(
      (event) {
        _handleDiscovery(event);
      },
      onError: (e) => debugPrint('$_tag Discovery error: $e'),
    );

    // Start discovery with optional service UUID filter
    await _central.startDiscovery(serviceUUIDs: [meshServiceUuid]);
    debugPrint('$_tag Started BLE discovery');
  }

  /// Handles a discovery event - initiates connection if not already connected/connecting.
  void _handleDiscovery(DiscoveredEventArgs event) async {
    final peripheral = event.peripheral;
    final deviceUuid = peripheral.uuid.toString();

    // Skip if already connected or currently connecting
    if (_connectedDevices.containsKey(deviceUuid)) return;
    if (_connectingDevices.contains(deviceUuid)) return;

    // Check retry limit
    final attempts = _connectionAttempts[deviceUuid] ?? 0;
    if (attempts >= _maxConnectionRetries) {
      // Reset after a delay to allow future connection attempts
      Future.delayed(const Duration(minutes: 1), () {
        _connectionAttempts.remove(deviceUuid);
      });
      return;
    }

    _connectingDevices.add(deviceUuid);
    _connectionAttempts[deviceUuid] = attempts + 1;

    debugPrint(
        '$_tag Connecting to $deviceUuid (RSSI: ${event.rssi}, attempt ${attempts + 1}/$_maxConnectionRetries)');

    try {
      await _connectToDevice(peripheral);
      _connectionAttempts.remove(deviceUuid); // Reset on success
    } catch (e) {
      debugPrint('$_tag Connection failed for $deviceUuid: $e');
      _connectedDevices.remove(deviceUuid);
      _meshCharacteristics.remove(deviceUuid);

      // Schedule reconnection attempt
      if (_isActive && attempts + 1 < _maxConnectionRetries) {
        Future.delayed(_reconnectDelay, () {
          _connectingDevices.remove(deviceUuid);
        });
      }
    } finally {
      _connectingDevices.remove(deviceUuid);
    }
  }

  /// Connects to a peripheral with proper GATT operation sequencing.
  ///
  /// Follows Android BluetoothGattClientManager pattern:
  /// connect -> delay -> MTU -> delay -> discover -> delay -> setNotify -> delay -> ready
  Future<void> _connectToDevice(Peripheral peripheral) async {
    final deviceUuid = peripheral.uuid.toString();

    // Step 1: Connect with timeout
    await _central.connect(peripheral).timeout(
          _connectionTimeout,
          onTimeout: () => throw TimeoutException(
              'Connection timed out after ${_connectionTimeout.inSeconds}s'),
        );

    _connectedDevices[deviceUuid] = peripheral;
    debugPrint('$_tag Connected to $deviceUuid');

    // Delay before MTU negotiation (matching Android 200ms)
    await Future.delayed(_operationDelay);

    // Step 2: MTU Negotiation (if enabled)
    if (AppConstants.requestMtu) {
      try {
        debugPrint(
            '$_tag Requesting MTU ${AppConstants.requestedMtuSize} for $deviceUuid');
        final mtu = await _central.requestMTU(
          peripheral,
          mtu: AppConstants.requestedMtuSize,
        );
        debugPrint('$_tag MTU negotiated: $mtu for $deviceUuid');
      } catch (e) {
        debugPrint('$_tag MTU request failed for $deviceUuid: $e');
        // Continue anyway - some devices don't support MTU negotiation
      }
      await Future.delayed(_operationDelay);
    } else {
      debugPrint('$_tag MTU negotiation disabled for $deviceUuid');
    }

    // Step 3: Discover GATT services (with retry for flaky connections)
    List<GATTService> services = [];
    const maxDiscoveryRetries = 3;
    for (int attempt = 1; attempt <= maxDiscoveryRetries; attempt++) {
      debugPrint(
          '$_tag Discovering GATT services for $deviceUuid (attempt $attempt/$maxDiscoveryRetries)');
      services = await _central.discoverGATT(peripheral);
      debugPrint('$_tag Found ${services.length} services on $deviceUuid');

      if (services.isNotEmpty) break;

      // Retry with delay if no services found
      if (attempt < maxDiscoveryRetries) {
        debugPrint('$_tag No services found, retrying after delay...');
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    await Future.delayed(_operationDelay);

    // Step 4: Find our mesh service and characteristic
    GATTCharacteristic? meshCharacteristic;
    final meshServiceUuid = UUID.fromString(AppConstants.meshServiceUuid);
    final meshCharUuid = UUID.fromString(AppConstants.meshCharacteristicUuid);

    for (var service in services) {
      if (service.uuid == meshServiceUuid) {
        debugPrint('$_tag Found mesh service on $deviceUuid');

        for (var characteristic in service.characteristics) {
          if (characteristic.uuid == meshCharUuid) {
            meshCharacteristic = characteristic;
            debugPrint('$_tag Found mesh characteristic on $deviceUuid');
            debugPrint(
                '$_tag   Properties: notify=${characteristic.properties.contains(GATTCharacteristicProperty.notify)}, indicate=${characteristic.properties.contains(GATTCharacteristicProperty.indicate)}, write=${characteristic.properties.contains(GATTCharacteristicProperty.write)}, writeNoResponse=${characteristic.properties.contains(GATTCharacteristicProperty.writeWithoutResponse)}');
            break;
          }
        }
        break;
      }
    }

    if (meshCharacteristic == null) {
      throw Exception('Mesh characteristic not found on $deviceUuid');
    }

    // Cache the characteristic for later use
    _meshCharacteristics[deviceUuid] = meshCharacteristic;

    await Future.delayed(_operationDelay);

    // Step 5: Enable notifications
    bool notificationsEnabled = false;
    try {
      await _enableNotificationsWithRetry(peripheral, meshCharacteristic);
      notificationsEnabled = true;
    } catch (e) {
      debugPrint('$_tag Failed to enable notifications on $deviceUuid: $e');
      // Continue anyway - we might still be able to write to the device
    }

    await Future.delayed(_operationDelay);

    // Step 6: Notify delegate - connection complete
    delegate?.onDeviceConnected(peripheral);
    debugPrint(
        '$_tag Connection setup complete for $deviceUuid (notifications=${notificationsEnabled ? "enabled" : "failed"})');
  }

  /// Enables notifications with retry logic.
  Future<void> _enableNotificationsWithRetry(
    Peripheral peripheral,
    GATTCharacteristic characteristic,
  ) async {
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 500);
    final deviceUuid = peripheral.uuid.toString();

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '$_tag Enabling notifications for $deviceUuid (attempt $attempt/$maxRetries)');

        await _central
            .setCharacteristicNotifyState(
              peripheral,
              characteristic,
              state: true,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () =>
                  throw TimeoutException('setNotifyState timed out after 5s'),
            );

        debugPrint('$_tag Notifications enabled for $deviceUuid');
        return;
      } catch (e) {
        debugPrint('$_tag setNotifyState attempt $attempt failed: $e');

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        } else {
          debugPrint(
              '$_tag Warning: Could not enable notifications after $maxRetries attempts');
          rethrow;
        }
      }
    }
  }

  /// Handles incoming characteristic value changes.
  void _onCharacteristicChanged(Peripheral peripheral, Uint8List value) {
    if (value.isEmpty) return;

    final deviceUuid = peripheral.uuid.toString();
    final packet = BitchatPacket.decode(value);

    if (packet != null) {
      delegate?.onPacketReceived(packet, deviceUuid, peripheral);
    } else {
      debugPrint(
          '$_tag Failed to decode packet from $deviceUuid (${value.length} bytes)');
    }
  }

  /// Sends a packet to a specific peripheral.
  ///
  /// Returns true if the packet was sent successfully, false otherwise.
  Future<bool> sendPacket(Peripheral peripheral, BitchatPacket packet) async {
    final deviceUuid = peripheral.uuid.toString();

    try {
      // Get cached characteristic
      final characteristic = _meshCharacteristics[deviceUuid];
      if (characteristic == null) {
        debugPrint(
            '$_tag No cached characteristic for $deviceUuid, cannot send');
        return false;
      }

      // Use the packet's senderID when encoding so the receiver can map the sender
      final Uint8List senderIdForEncode = packet.senderID ?? Uint8List(8);
      final encoded = PacketCodec.encode(
        packet,
        senderID: senderIdForEncode,
        signature: packet.signature,
        isCompressed: false,
      );

      if (encoded == null) {
        debugPrint('$_tag Failed to encode packet for $deviceUuid');
        return false;
      }

      // Use writeWithoutResponse for better performance if supported
      final supportsWriteNoResponse = characteristic.properties
          .contains(GATTCharacteristicProperty.writeWithoutResponse);

      final writeType = supportsWriteNoResponse
          ? GATTCharacteristicWriteType.withoutResponse
          : GATTCharacteristicWriteType.withResponse;

      debugPrint(
          '$_tag Sending ${encoded.length} bytes to $deviceUuid (writeNoResponse: $supportsWriteNoResponse)');

      await _central.writeCharacteristic(
        peripheral,
        characteristic,
        value: encoded,
        type: writeType,
      );

      debugPrint('$_tag Write to $deviceUuid completed');
      return true;
    } catch (e) {
      debugPrint('$_tag Failed to send packet to $deviceUuid: $e');
      return false;
    }
  }

  /// Sends a packet to all connected peripherals.
  ///
  /// Returns the number of successful sends.
  Future<int> broadcastPacket(BitchatPacket packet) async {
    int successCount = 0;

    for (var entry in _connectedDevices.entries) {
      if (await sendPacket(entry.value, packet)) {
        successCount++;
      }
    }

    return successCount;
  }

  /// Returns the list of currently connected device UUIDs.
  List<String> getConnectedDevices() {
    return _connectedDevices.keys.toList();
  }

  /// Returns the number of connected devices.
  int getConnectedCount() {
    return _connectedDevices.length;
  }

  /// Returns whether a specific device is connected.
  bool isDeviceConnected(String deviceUuid) {
    return _connectedDevices.containsKey(deviceUuid);
  }

  /// Returns debug information about the manager state.
  Map<String, dynamic> getDebugInfo() {
    return {
      'isActive': _isActive,
      'connectedDevices': _connectedDevices.keys.toList(),
      'connectingDevices': _connectingDevices.toList(),
      'connectionAttempts': Map.from(_connectionAttempts),
      'cachedCharacteristics': _meshCharacteristics.keys.toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Manual Connection Control (Debug UI)
  // ---------------------------------------------------------------------------

  /// Disconnects a peripheral by its UUID/address string.
  /// Used by debug UI for manual disconnect.
  Future<void> disconnectByAddress(String deviceAddress) async {
    final peripheral = _connectedDevices[deviceAddress];
    if (peripheral != null) {
      try {
        await _central.disconnect(peripheral);
        debugPrint('$_tag Manually disconnected: $deviceAddress');
      } catch (e) {
        debugPrint('$_tag Error disconnecting $deviceAddress: $e');
      }
    } else {
      debugPrint('$_tag Device $deviceAddress not found in connected devices');
    }
  }

  /// Initiates connection to a peripheral by its UUID/address string.
  /// Looks up the peripheral in recently discovered devices.
  /// Used by debug UI for manual connect from scan results.
  Future<void> connectByAddress(String deviceAddress) async {
    // Check if already connected or connecting
    if (_connectedDevices.containsKey(deviceAddress)) {
      debugPrint('$_tag Already connected to $deviceAddress');
      return;
    }
    if (_connectingDevices.contains(deviceAddress)) {
      debugPrint('$_tag Already connecting to $deviceAddress');
      return;
    }

    // For now, we need to discover the device again to get the peripheral
    // The bluetooth_low_energy package doesn't provide a way to connect by address directly
    // The device should be rediscovered through normal scanning
    debugPrint(
        '$_tag Manual connect requested for $deviceAddress - device will be connected on next discovery');

    // Reset connection attempts to allow immediate reconnection
    _connectionAttempts.remove(deviceAddress);
  }
}
