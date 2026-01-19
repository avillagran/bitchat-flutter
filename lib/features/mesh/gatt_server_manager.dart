import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import 'package:bitchat/core/constants.dart';

/// Delegate for GATT server events
abstract class GattServerDelegate {
  /// Called when data is received from a connected peer
  void onDataReceived(Uint8List data, String deviceAddress);
}

/// GattServerManager - Manages BLE peripheral mode with full GATT server.
///
/// Uses bluetooth_low_energy package which supports:
/// - Full GATT server with read/write/notify characteristics
/// - Cross-platform (Android, iOS, macOS, Windows)
/// - Note: Linux does NOT support peripheral mode (bluez limitation)
///
/// The server exposes a custom mesh service with a characteristic that
/// supports read, write, write-without-response, and notify operations.
class GattServerManager {
  static const String _tag = '[GattServerManager]';

  bool _isActive = false;
  late final PeripheralManager _peripheralManager;

  /// Connected centrals that have subscribed to notifications
  final Map<String, Central> _subscribedCentrals = {};

  /// All connected centrals (by address)
  final Map<String, Central> _connectedCentrals = {};

  /// Cached characteristic for notifications
  GATTCharacteristic? _meshCharacteristic;

  /// Current value stored in the characteristic (for read requests)
  Uint8List _characteristicValue = Uint8List(0);

  /// BLE reassembly buffer per central (for handling low MTU chunked writes)
  /// Key: central UUID, Value: accumulated bytes
  final Map<String, List<int>> _reassemblyBuffer = {};

  /// Timestamp of last data received per central (for timeout cleanup)
  final Map<String, DateTime> _reassemblyTimestamp = {};

  /// Maximum reassembly buffer size (prevent memory exhaustion)
  static const int _maxReassemblyBufferSize = 2048;

  /// Reassembly timeout in milliseconds
  static const int _reassemblyTimeoutMs = 5000;

  /// Stream subscriptions
  StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>?
      _stateSubscription;
  StreamSubscription<GATTCharacteristicReadRequestedEventArgs>?
      _readSubscription;
  StreamSubscription<GATTCharacteristicWriteRequestedEventArgs>?
      _writeSubscription;
  StreamSubscription<GATTCharacteristicNotifyStateChangedEventArgs>?
      _notifyStateSubscription;
  StreamSubscription<GATTDescriptorWriteRequestedEventArgs>?
      _descriptorWriteSubscription;

  GattServerDelegate? delegate;

  /// Whether the server is currently active
  bool get isActive => _isActive;

  /// Number of connected centrals
  int get connectedCount => _connectedCentrals.length;

  /// Number of subscribed centrals (for notifications)
  int get subscribedCount => _subscribedCentrals.length;

  /// Start BLE GATT server as a peripheral.
  /// This creates a GATT service, adds characteristics, and starts advertising.
  ///
  /// Returns true if the server started successfully.
  Future<bool> start() async {
    if (_isActive) {
      debugPrint('$_tag Already active');
      return true;
    }

    // Platform check: Linux doesn't support BLE peripheral mode
    if (Platform.isLinux) {
      debugPrint('$_tag BLE peripheral mode not supported on Linux');
      return false;
    }

    try {
      // Initialize the peripheral manager
      _peripheralManager = PeripheralManager();
      debugPrint('$_tag PeripheralManager initialized');

      // Check Bluetooth state
      final state = _peripheralManager.state;
      if (state != BluetoothLowEnergyState.poweredOn) {
        debugPrint('$_tag Bluetooth not powered on (state: $state)');

        // Try to authorize if unauthorized (Android and macOS)
        if (state == BluetoothLowEnergyState.unauthorized) {
          debugPrint('$_tag Requesting Bluetooth authorization...');
          try {
            await _peripheralManager.authorize();
            // Re-check state after authorization
            final newState = _peripheralManager.state;
            debugPrint('$_tag State after authorization: $newState');
            if (newState == BluetoothLowEnergyState.poweredOn) {
              // Authorization succeeded, continue with setup
              debugPrint('$_tag Authorization successful, continuing setup');
            } else {
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

      // Set up event listeners
      _setupEventListeners();

      // Create and add the GATT service
      await _setupGattService();

      // Start advertising
      await _startAdvertising();

      _isActive = true;
      debugPrint('$_tag GATT server started successfully');
      debugPrint('$_tag Debug info: ${getDebugInfo()}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('$_tag Failed to start GATT server: $e');
      debugPrint('$_tag Stack trace: $stackTrace');
      _cleanup();
      return false;
    }
  }

  /// Stop the GATT server and release resources.
  void stop() {
    if (!_isActive) {
      debugPrint('$_tag Already stopped');
      return;
    }

    debugPrint('$_tag Stopping GATT server');
    _cleanup();
    debugPrint('$_tag GATT server stopped');
  }

  /// Send data to connected centrals via notifications.
  ///
  /// If [targetDevice] is null, sends to all subscribed centrals.
  /// If [targetDevice] is specified, sends only to that central.
  ///
  /// Returns true if data was sent to at least one central.
  Future<bool> sendData(Uint8List data, String? targetDevice) async {
    if (!_isActive) {
      debugPrint('$_tag Cannot send data: server not active');
      return false;
    }

    if (_meshCharacteristic == null) {
      debugPrint('$_tag Cannot send data: characteristic not available');
      return false;
    }

    if (_subscribedCentrals.isEmpty) {
      debugPrint('$_tag Cannot send data: no subscribed centrals');
      return false;
    }

    bool sentToAny = false;

    try {
      if (targetDevice != null) {
        // Send to specific device
        final central = _subscribedCentrals[targetDevice];
        if (central != null) {
          await _peripheralManager.notifyCharacteristic(
            central,
            _meshCharacteristic!,
            value: data,
          );
          debugPrint(
              '$_tag Sent ${data.length} bytes to $targetDevice via notification');
          sentToAny = true;
        } else {
          debugPrint('$_tag Target device $targetDevice not subscribed');
        }
      } else {
        // Send to all subscribed centrals
        // Create a copy to avoid concurrent modification
        final entries = _subscribedCentrals.entries.toList();
        for (final entry in entries) {
          try {
            await _peripheralManager.notifyCharacteristic(
              entry.value,
              _meshCharacteristic!,
              value: data,
            );
            debugPrint(
                '$_tag Sent ${data.length} bytes to ${entry.key} via notification');
            sentToAny = true;
          } catch (e) {
            debugPrint('$_tag Failed to notify ${entry.key}: $e');
            // Remove failed central from subscribed list
            _subscribedCentrals.remove(entry.key);
          }
        }
      }
    } catch (e) {
      debugPrint('$_tag Error sending data: $e');
    }

    return sentToAny;
  }

  /// Send data to all CONNECTED centrals (not just subscribed) via notifications.
  /// This is useful when Android connects but doesn't subscribe to notifications.
  /// The notification will be attempted for all connected centrals.
  ///
  /// Returns true if data was sent to at least one central.
  Future<bool> sendDataToAllConnected(Uint8List data) async {
    if (!_isActive) {
      debugPrint('$_tag Cannot send data: server not active');
      return false;
    }

    if (_meshCharacteristic == null) {
      debugPrint('$_tag Cannot send data: characteristic not available');
      return false;
    }

    if (_connectedCentrals.isEmpty) {
      debugPrint('$_tag Cannot send data: no connected centrals');
      return false;
    }

    bool sentToAny = false;

    // Update the characteristic value so centrals can read it
    _characteristicValue = data;

    // Try to notify all connected centrals
    final entries = _connectedCentrals.entries.toList();
    for (final entry in entries) {
      try {
        await _peripheralManager.notifyCharacteristic(
          entry.value,
          _meshCharacteristic!,
          value: data,
        );
        debugPrint(
            '$_tag Sent ${data.length} bytes to ${entry.key} via notification (connected)');
        sentToAny = true;
      } catch (e) {
        debugPrint('$_tag Failed to notify connected ${entry.key}: $e');
        // Don't remove from connected list - just log the error
      }
    }

    return sentToAny;
  }

  /// Send data to a SPECIFIC central by its address.
  /// This is used when we need to route a message to a known peer that connected to us.
  ///
  /// Returns true if data was sent successfully.
  Future<bool> sendToSpecificCentral(
      Uint8List data, String centralAddress) async {
    if (!_isActive) {
      debugPrint('$_tag Cannot send data: server not active');
      return false;
    }

    if (_meshCharacteristic == null) {
      debugPrint('$_tag Cannot send data: characteristic not available');
      return false;
    }

    // Find the central by address (case-insensitive match)
    final addressLower = centralAddress.toLowerCase();
    Central? targetCentral;
    String? matchedKey;

    for (final entry in _connectedCentrals.entries) {
      if (entry.key.toLowerCase() == addressLower) {
        targetCentral = entry.value;
        matchedKey = entry.key;
        break;
      }
    }

    if (targetCentral == null) {
      debugPrint(
          '$_tag Central $centralAddress not found in connected centrals');
      debugPrint(
          '$_tag Available centrals: ${_connectedCentrals.keys.toList()}');
      return false;
    }

    try {
      // Update characteristic value for read access
      _characteristicValue = data;

      final isSubscribed = _subscribedCentrals.containsKey(matchedKey);
      debugPrint(
          '$_tag Sending to specific central $matchedKey (subscribed: $isSubscribed)');

      // Send notification to this specific central
      await _peripheralManager.notifyCharacteristic(
        targetCentral,
        _meshCharacteristic!,
        value: data,
      );
      debugPrint(
          '$_tag Sent ${data.length} bytes to specific central $matchedKey');
      return true;
    } catch (e) {
      debugPrint('$_tag Failed to send to central $centralAddress: $e');
      return false;
    }
  }

  /// Checks if a specific central is connected by address.
  bool isCentralConnected(String centralAddress) {
    final addressLower = centralAddress.toLowerCase();
    return _connectedCentrals.keys.any((k) => k.toLowerCase() == addressLower);
  }

  /// Get debug information about the server state
  Map<String, dynamic> getDebugInfo() {
    return {
      'isActive': _isActive,
      'serviceUuid': AppConstants.meshServiceUuid,
      'characteristicUuid': AppConstants.meshCharacteristicUuid,
      'connectedCentrals': _connectedCentrals.keys.toList(),
      'subscribedCentrals': _subscribedCentrals.keys.toList(),
      'hasCharacteristic': _meshCharacteristic != null,
    };
  }

  /// Sets up event listeners for the peripheral manager
  void _setupEventListeners() {
    // Listen for Bluetooth state changes
    _stateSubscription = _peripheralManager.stateChanged.listen((eventArgs) {
      debugPrint('$_tag Bluetooth state changed: ${eventArgs.state}');
      if (eventArgs.state != BluetoothLowEnergyState.poweredOn && _isActive) {
        debugPrint('$_tag Bluetooth turned off, stopping server');
        stop();
      }
    });

    // Listen for characteristic read requests
    _readSubscription =
        _peripheralManager.characteristicReadRequested.listen((eventArgs) {
      _handleReadRequest(eventArgs);
    });

    // Listen for characteristic write requests
    _writeSubscription =
        _peripheralManager.characteristicWriteRequested.listen((eventArgs) {
      _handleWriteRequest(eventArgs);
    });

    // Listen for notification subscription changes
    _notifyStateSubscription =
        _peripheralManager.characteristicNotifyStateChanged.listen((eventArgs) {
      debugPrint('$_tag Event fired: characteristicNotifyStateChanged');
      debugPrint(
          '$_tag Event details: central=${eventArgs.central.uuid}, state=${eventArgs.state}');
      _handleNotifyStateChanged(eventArgs);
      debugPrint(
          '$_tag After handling notify state change - subscribedCount=${_subscribedCentrals.length}');
    });

    // Listen for descriptor write requests (e.g., CCCD writes from centrals)
    // Note: This is not supported on Darwin (macOS/iOS) - the framework handles CCCD internally
    if (!Platform.isMacOS && !Platform.isIOS) {
      _descriptorWriteSubscription =
          _peripheralManager.descriptorWriteRequested.listen((eventArgs) {
        debugPrint('$_tag Event fired: descriptorWriteRequested');
        debugPrint(
            '$_tag Descriptor write details: descriptor=${eventArgs.descriptor.uuid}, central=${eventArgs.central.uuid}, value=${eventArgs.request.value}');
        _handleDescriptorWriteRequest(eventArgs);
        debugPrint(
            '$_tag After handling descriptor write - subscribedCount=${_subscribedCentrals.length}');
      });
    } else {
      debugPrint('$_tag Skipping descriptorWriteRequested listener (not supported on Darwin)');
    }

    debugPrint('$_tag Event listeners set up');
  }

  /// Creates and adds the GATT service with mesh characteristic
  Future<void> _setupGattService() async {
    // Remove any existing services first
    await _peripheralManager.removeAllServices();

    // Create descriptors list - CCCD is handled automatically on Darwin
    // Adding CCCD manually on Darwin causes CBErrorDomain Code=1 "invalid parameters"
    final List<GATTDescriptor> descriptors;
    if (Platform.isMacOS || Platform.isIOS) {
      // Darwin: CoreBluetooth automatically adds CCCD when notify property is set
      descriptors = [];
      debugPrint('$_tag Darwin: Skipping manual CCCD descriptor (handled by framework)');
    } else {
      // Android/Windows: Need to add CCCD descriptor manually
      final cccdDescriptor = GATTDescriptor.immutable(
        uuid: UUID.fromString(AppConstants.meshDescriptorUuid),
        value: Uint8List.fromList([0x00, 0x00]),
      );
      descriptors = [cccdDescriptor];
      debugPrint('$_tag Added CCCD descriptor for non-Darwin platform');
    }

    // Create the mesh characteristic with read/write/notify support
    // Using the factory method for mutable characteristics
    _meshCharacteristic = GATTCharacteristic.mutable(
      uuid: UUID.fromString(AppConstants.meshCharacteristicUuid),
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
      descriptors: descriptors,
    );
    debugPrint('$_tag Created characteristic with ${descriptors.length} descriptors');

    // Create the mesh service
    final service = GATTService(
      uuid: UUID.fromString(AppConstants.meshServiceUuid),
      isPrimary: true,
      includedServices: [],
      characteristics: [_meshCharacteristic!],
    );

    // Add the service to the GATT server
    await _peripheralManager.addService(service);

    debugPrint('$_tag GATT service added:');
    debugPrint('$_tag   Service UUID: ${AppConstants.meshServiceUuid}');
    debugPrint(
        '$_tag   Characteristic UUID: ${AppConstants.meshCharacteristicUuid}');
  }

  /// Starts BLE advertising with the mesh service UUID
  Future<void> _startAdvertising() async {
    // Build manufacturer specific data list
    // Note: iOS/macOS don't support manufacturer data in advertising
    final List<ManufacturerSpecificData> manufacturerData;
    if (Platform.isIOS || Platform.isMacOS) {
      manufacturerData = [];
    } else {
      manufacturerData = [
        ManufacturerSpecificData(
          id: 0xB17C, // Custom manufacturer ID (matching Android)
          data: Uint8List.fromList([0x42, 0x49, 0x54]), // "BIT" as identifier
        ),
      ];
    }

    // On macOS, don't include name to minimize advertisement size
    // This helps ensure legacy advertising mode which Android's scanner can see
    final String? advertiseName = Platform.isMacOS ? null : 'bitchat';

    final advertisement = Advertisement(
      name: advertiseName,
      serviceUUIDs: [UUID.fromString(AppConstants.meshServiceUuid)],
      manufacturerSpecificData: manufacturerData,
    );

    await _peripheralManager.startAdvertising(advertisement);

    debugPrint('$_tag Advertising started with:');
    debugPrint('$_tag   Name: ${advertiseName ?? "(none - macOS legacy mode)"}');
    debugPrint('$_tag   Service UUID: ${AppConstants.meshServiceUuid}');
  }

  /// Handles read requests on the mesh characteristic
  void _handleReadRequest(
      GATTCharacteristicReadRequestedEventArgs eventArgs) async {
    if (!_isActive) {
      debugPrint('$_tag Ignoring read request: server not active');
      return;
    }

    final central = eventArgs.central;
    final characteristic = eventArgs.characteristic;
    final request = eventArgs.request;
    final centralAddress = central.uuid.toString();

    debugPrint(
        '$_tag Read request from $centralAddress for ${characteristic.uuid}, offset: ${request.offset}');

    // Track connected central
    _connectedCentrals[centralAddress] = central;

    // Respond with the current characteristic value (handle offset)
    try {
      final value = request.offset < _characteristicValue.length
          ? _characteristicValue.sublist(request.offset)
          : Uint8List(0);

      await _peripheralManager.respondReadRequestWithValue(
        request,
        value: value,
      );
      debugPrint('$_tag Responded with ${value.length} bytes to read request');
    } catch (e) {
      debugPrint('$_tag Error responding to read request: $e');
    }
  }

  /// Handles write requests on the mesh characteristic with BLE reassembly support.
  ///
  /// When Android sends packets without MTU negotiation, data arrives in 20-byte chunks.
  /// This method accumulates chunks until a complete packet is received, then passes
  /// it to the delegate.
  void _handleWriteRequest(
      GATTCharacteristicWriteRequestedEventArgs eventArgs) async {
    if (!_isActive) {
      debugPrint('$_tag Ignoring write request: server not active');
      return;
    }

    final central = eventArgs.central;
    final request = eventArgs.request;
    final centralAddress = central.uuid.toString();
    final data = request.value;

    debugPrint('$_tag ========================================');
    debugPrint('$_tag WRITE REQUEST RECEIVED');
    debugPrint('$_tag Central: $centralAddress');
    debugPrint('$_tag Chunk size: ${data.length} bytes');
    debugPrint('$_tag ========================================');

    // Track connected central
    _connectedCentrals[centralAddress] = central;

    // Respond to the write request immediately (required for write-with-response)
    try {
      await _peripheralManager.respondWriteRequest(request);
    } catch (e) {
      debugPrint('$_tag Error responding to write request: $e');
    }

    if (data.isEmpty) {
      debugPrint('$_tag Data is empty, ignoring');
      return;
    }

    // Check for timeout on existing buffer
    final lastTimestamp = _reassemblyTimestamp[centralAddress];
    if (lastTimestamp != null) {
      final elapsed = DateTime.now().difference(lastTimestamp).inMilliseconds;
      if (elapsed > _reassemblyTimeoutMs) {
        debugPrint('$_tag Reassembly timeout for $centralAddress, clearing buffer');
        _reassemblyBuffer.remove(centralAddress);
        _reassemblyTimestamp.remove(centralAddress);
      }
    }

    // Initialize or get existing buffer
    _reassemblyBuffer[centralAddress] ??= [];
    final buffer = _reassemblyBuffer[centralAddress]!;

    // Append new data
    buffer.addAll(data);
    _reassemblyTimestamp[centralAddress] = DateTime.now();

    debugPrint('$_tag Buffer now has ${buffer.length} bytes for $centralAddress');

    // Check buffer size limit
    if (buffer.length > _maxReassemblyBufferSize) {
      debugPrint('$_tag Buffer exceeded max size, clearing for $centralAddress');
      _reassemblyBuffer.remove(centralAddress);
      _reassemblyTimestamp.remove(centralAddress);
      return;
    }

    // Try to extract complete packets from buffer
    _tryProcessBuffer(centralAddress);
  }

  /// Attempts to process complete packets from the reassembly buffer.
  /// Uses packet header to determine expected size.
  void _tryProcessBuffer(String centralAddress) {
    final buffer = _reassemblyBuffer[centralAddress];
    if (buffer == null || buffer.isEmpty) return;

    // Need at least minimum header size to determine packet structure
    // V1: 14 bytes header + 8 bytes sender = 22 minimum
    // V2: 16 bytes header + 8 bytes sender = 24 minimum
    const minHeaderV1 = 14;
    const minHeaderV2 = 16;
    const senderIdSize = 8;

    while (buffer.length >= minHeaderV1 + senderIdSize) {
      final version = buffer[0];

      // Validate version
      if (version != 1 && version != 2) {
        debugPrint('$_tag Invalid version $version in buffer, clearing');
        _reassemblyBuffer.remove(centralAddress);
        _reassemblyTimestamp.remove(centralAddress);
        return;
      }

      final headerSize = version == 1 ? minHeaderV1 : minHeaderV2;
      final minSize = headerSize + senderIdSize;

      if (buffer.length < minSize) {
        debugPrint('$_tag Need $minSize bytes for header, have ${buffer.length}, waiting...');
        return; // Need more data
      }

      // Parse header to calculate expected size
      // Header: version(1) + type(1) + ttl(1) + timestamp(8) + flags(1) + payloadLength(2 or 4)
      final flags = buffer[11]; // flags at offset 11 (after version+type+ttl+timestamp)
      final hasRecipient = (flags & 0x01) != 0;
      final hasSignature = (flags & 0x02) != 0;
      final hasRoute = (version >= 2) && (flags & 0x08) != 0;

      // Read payload length
      final int payloadLength;
      if (version >= 2) {
        if (buffer.length < 16) {
          debugPrint('$_tag Need 16 bytes for V2 header, have ${buffer.length}, waiting...');
          return;
        }
        payloadLength = (buffer[12] << 24) | (buffer[13] << 16) | (buffer[14] << 8) | buffer[15];
      } else {
        payloadLength = (buffer[12] << 8) | buffer[13];
      }

      // Calculate expected total size
      int expectedSize = headerSize + senderIdSize + payloadLength;
      if (hasRecipient) expectedSize += 8; // recipientIdSize
      if (hasSignature) expectedSize += 64; // signatureSize

      // Handle route: 1 byte count + (count * 8) bytes for hop IDs
      if (hasRoute) {
        final routeOffset = headerSize + senderIdSize + (hasRecipient ? 8 : 0);
        if (buffer.length <= routeOffset) {
          debugPrint('$_tag Need more data to read route count');
          return;
        }
        final routeCount = buffer[routeOffset] & 0xFF;
        expectedSize += 1 + (routeCount * 8);
      }

      debugPrint('$_tag Expected packet size: $expectedSize, buffer has: ${buffer.length}');

      if (buffer.length < expectedSize) {
        debugPrint('$_tag Waiting for more data (${buffer.length}/$expectedSize bytes)');
        return; // Need more data
      }

      // Extract complete packet
      final packetData = Uint8List.fromList(buffer.sublist(0, expectedSize));

      // Remove processed bytes from buffer
      buffer.removeRange(0, expectedSize);

      debugPrint('$_tag Extracted complete packet: $expectedSize bytes');
      debugPrint('$_tag Remaining in buffer: ${buffer.length} bytes');

      // Update characteristic value
      _characteristicValue = packetData;

      // Notify delegate
      debugPrint('$_tag Calling delegate.onDataReceived with reassembled packet...');
      delegate?.onDataReceived(packetData, centralAddress);
      debugPrint('$_tag delegate.onDataReceived call completed');
    }

    // Clean up empty buffer
    if (buffer.isEmpty) {
      _reassemblyBuffer.remove(centralAddress);
      _reassemblyTimestamp.remove(centralAddress);
    }
  }

  /// Clears reassembly buffer for a specific central (call on disconnect)
  void _clearReassemblyBuffer(String centralAddress) {
    _reassemblyBuffer.remove(centralAddress);
    _reassemblyTimestamp.remove(centralAddress);
  }

  /// Handles notification subscription state changes
  void _handleNotifyStateChanged(
      GATTCharacteristicNotifyStateChangedEventArgs eventArgs) {
    if (!_isActive) {
      debugPrint('$_tag Ignoring notify state change: server not active');
      return;
    }

    final central = eventArgs.central;
    final centralAddress = central.uuid.toString();
    final isSubscribed = eventArgs.state;

    debugPrint(
        '$_tag Notify state changed for $centralAddress: ${isSubscribed ? "subscribed" : "unsubscribed"}');

    if (isSubscribed) {
      _subscribedCentrals[centralAddress] = central;
      _connectedCentrals[centralAddress] = central;
      debugPrint('$_tag Central $centralAddress subscribed to notifications');
    } else {
      _subscribedCentrals.remove(centralAddress);
      _clearReassemblyBuffer(centralAddress); // Clean up on disconnect
      debugPrint(
          '$_tag Central $centralAddress unsubscribed from notifications');
    }

    debugPrint(
        '$_tag Total subscribed centrals: ${_subscribedCentrals.length}');
  }

  /// Handles descriptor write requests (e.g., CCCD writes for enabling/disabling notifications)
  void _handleDescriptorWriteRequest(
      GATTDescriptorWriteRequestedEventArgs eventArgs) async {
    if (!_isActive) {
      debugPrint('$_tag Ignoring descriptor write: server not active');
      return;
    }

    final descriptor = eventArgs.descriptor;
    final central = eventArgs.central;
    final request = eventArgs.request;
    final centralAddress = central.uuid.toString();

    debugPrint(
        '$_tag Descriptor write requested from $centralAddress for descriptor ${descriptor.uuid}');

    // Only handle CCCD writes
    final cccdUuid = UUID.fromString(AppConstants.meshDescriptorUuid);
    if (descriptor.uuid != cccdUuid) {
      debugPrint(
          '$_tag Ignoring descriptor write: descriptor UUID does not match CCCD');
      try {
        await _peripheralManager.respondWriteRequest(request);
      } catch (e) {
        debugPrint('$_tag Error responding to descriptor write request: $e');
      }
      return;
    }

    final value = request.value;

    // Value [0x01, 0x00] => enable notifications
    // Value [0x00, 0x00] => disable notifications
    if (value.length >= 2 && value[0] == 0x01 && value[1] == 0x00) {
      _subscribedCentrals[centralAddress] = central;
      _connectedCentrals[centralAddress] = central;
      debugPrint(
          '$_tag CCCD write: enabling notifications for $centralAddress');
    } else if (value.length >= 2 && value[0] == 0x00 && value[1] == 0x00) {
      _subscribedCentrals.remove(centralAddress);
      debugPrint(
          '$_tag CCCD write: disabling notifications for $centralAddress');
    } else {
      debugPrint(
          '$_tag CCCD write: unknown value ${value} from $centralAddress');
    }

    debugPrint(
        '$_tag Subscribed count after descriptor write: ${_subscribedCentrals.length}');

    // Respond to the descriptor write request to acknowledge
    try {
      await _peripheralManager.respondWriteRequest(request);
    } catch (e) {
      debugPrint('$_tag Error responding to descriptor write request: $e');
    }
  }

  /// Cleans up resources and resets state
  void _cleanup() {
    _isActive = false;

    // Cancel subscriptions
    _stateSubscription?.cancel();
    _stateSubscription = null;

    _readSubscription?.cancel();
    _readSubscription = null;

    _writeSubscription?.cancel();
    _writeSubscription = null;

    _notifyStateSubscription?.cancel();
    _notifyStateSubscription = null;

    _descriptorWriteSubscription?.cancel();
    _descriptorWriteSubscription = null;

    // Stop advertising
    try {
      _peripheralManager.stopAdvertising();
    } catch (e) {
      debugPrint('$_tag Error stopping advertising: $e');
    }

    // Remove all services
    try {
      _peripheralManager.removeAllServices();
    } catch (e) {
      debugPrint('$_tag Error removing services: $e');
    }

    // Clear state
    _subscribedCentrals.clear();
    _connectedCentrals.clear();
    _meshCharacteristic = null;
    _characteristicValue = Uint8List(0);
    _reassemblyBuffer.clear();
    _reassemblyTimestamp.clear();

    debugPrint('$_tag Cleanup complete');
  }

  // ---------------------------------------------------------------------------
  // Manual Connection Control (Debug UI)
  // ---------------------------------------------------------------------------

  /// Disconnects a central device by its address.
  /// Note: The bluetooth_low_energy PeripheralManager doesn't expose a direct
  /// disconnect method for centrals. The central controls the connection.
  /// This method removes the central from our tracking and stops sending
  /// notifications to it.
  void disconnectCentral(String centralAddress) {
    final central = _connectedCentrals.remove(centralAddress);
    _subscribedCentrals.remove(centralAddress);

    if (central != null) {
      debugPrint(
          '$_tag Removed central $centralAddress from tracking (central controls disconnect)');
    } else {
      debugPrint('$_tag Central $centralAddress not found in connected list');
    }
  }
}
