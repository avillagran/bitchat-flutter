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

  /// Track devices that failed "fast mode" service discovery.
  /// These will use "slow mode" (longer delays) on next connection.
  final Set<String> _slowModeDevices = {};

  /// Track devices that failed even "slow mode" service discovery.
  /// These will use "super slow mode" (even longer delays, no MTU, minimal operations).
  /// macOS-specific: helps with Android devices that have PHY negotiation issues.
  final Set<String> _superSlowModeDevices = {};

  /// Track consecutive connection failures per device for exponential backoff.
  /// macOS-specific: prevents hammering unstable connections.
  final Map<String, int> _consecutiveFailures = {};

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
    _slowModeDevices.clear();
    _superSlowModeDevices.clear();
    _consecutiveFailures.clear();
    debugPrint('$_tag Stopped');
  }

  /// Sets up all event subscriptions for the CentralManager.
  void _setupSubscriptions() {
    final isDarwin = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;

    // Listen for connection state changes
    _connectionStateSubscription =
        _central.connectionStateChanged.listen((event) {
      final deviceUuid = event.peripheral.uuid.toString();

      if (event.state == ConnectionState.disconnected) {
        // Device disconnected
        debugPrint('$_tag Device $deviceUuid disconnected');
        final wasConnected = _connectedDevices.containsKey(deviceUuid);
        final peripheral = _connectedDevices.remove(deviceUuid);
        _meshCharacteristics.remove(deviceUuid);

        if (peripheral != null) {
          delegate?.onDeviceDisconnected(peripheral);
        }

        // DARWIN FIX: Prevent rapid reconnection after disconnect
        // macOS + Android BLE connections are unstable due to PHY negotiation
        // Adding device to _connectingDevices prevents immediate reconnect
        if (isDarwin) {
          // If device was successfully connected but disconnected unexpectedly,
          // escalate to SLOW mode for next attempt (PHY instability likely)
          if (wasConnected && !_slowModeDevices.contains(deviceUuid)) {
            _slowModeDevices.add(deviceUuid);
            debugPrint('$_tag [Darwin] Unexpected disconnect - escalating to SLOW mode for $deviceUuid');
          }

          _connectingDevices.add(deviceUuid);
          debugPrint('$_tag [Darwin] Blocking reconnection for 3s after disconnect for $deviceUuid');
          Future.delayed(const Duration(seconds: 3), () {
            _connectingDevices.remove(deviceUuid);
            debugPrint('$_tag [Darwin] Reconnection allowed for $deviceUuid');
          });
        } else {
          // Non-Darwin: standard cleanup after short delay (matching Android pattern)
          Future.delayed(_cleanupDelay, () {
            _connectingDevices.remove(deviceUuid);
          });
        }
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
    final isDarwin = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;

    // Skip if already connected or currently connecting
    if (_connectedDevices.containsKey(deviceUuid)) return;
    if (_connectingDevices.contains(deviceUuid)) return;

    // Check retry limit
    final attempts = _connectionAttempts[deviceUuid] ?? 0;
    if (attempts >= _maxConnectionRetries) {
      // Reset after a delay to allow future connection attempts
      Future.delayed(const Duration(minutes: 1), () {
        _connectionAttempts.remove(deviceUuid);
        // Also reset failure tracking after cooldown
        if (isDarwin) {
          _consecutiveFailures.remove(deviceUuid);
        }
      });
      return;
    }

    _connectingDevices.add(deviceUuid);
    _connectionAttempts[deviceUuid] = attempts + 1;

    // DARWIN: Log connection mode for debugging
    if (isDarwin) {
      final mode = _superSlowModeDevices.contains(deviceUuid)
          ? 'SUPER_SLOW'
          : _slowModeDevices.contains(deviceUuid)
              ? 'SLOW'
              : 'FAST';
      final failures = _consecutiveFailures[deviceUuid] ?? 0;
      debugPrint(
          '$_tag [Darwin] Connecting to $deviceUuid (mode: $mode, failures: $failures, attempt ${attempts + 1}/$_maxConnectionRetries, RSSI: ${event.rssi})');
    } else {
      debugPrint(
          '$_tag Connecting to $deviceUuid (RSSI: ${event.rssi}, attempt ${attempts + 1}/$_maxConnectionRetries)');
    }

    try {
      await _connectToDevice(peripheral);
      _connectionAttempts.remove(deviceUuid); // Reset on success
      _connectingDevices.remove(deviceUuid);
      // DARWIN: Reset consecutive failures on success
      if (isDarwin) {
        _consecutiveFailures.remove(deviceUuid);
        debugPrint('$_tag [Darwin] Connection SUCCESS for $deviceUuid - reset failure counter');
      }
    } catch (e) {
      debugPrint('$_tag Connection failed for $deviceUuid: $e');
      _connectedDevices.remove(deviceUuid);
      _meshCharacteristics.remove(deviceUuid);

      // DARWIN: Track consecutive failures for exponential backoff
      if (isDarwin) {
        final failures = (_consecutiveFailures[deviceUuid] ?? 0) + 1;
        _consecutiveFailures[deviceUuid] = failures;

        // Exponential backoff: 2s, 4s, 8s, max 16s
        final backoffSeconds = (2 * (1 << (failures - 1).clamp(0, 3)));
        debugPrint('$_tag [Darwin] Failure #$failures for $deviceUuid - backoff ${backoffSeconds}s');

        Future.delayed(Duration(seconds: backoffSeconds), () {
          _connectingDevices.remove(deviceUuid);
        });
      } else {
        // Non-Darwin: standard 2s delay
        Future.delayed(const Duration(seconds: 2), () {
          _connectingDevices.remove(deviceUuid);
        });
      }
    }
  }

  /// Connects to a peripheral with proper GATT operation sequencing.
  ///
  /// Uses tri-strategy for Darwin connecting to potentially unstable devices:
  /// - Fast mode: Minimal delays, try service discovery before PHY negotiation settles
  /// - Slow mode: Long delays (3s+), for devices that failed fast mode
  /// - Super slow mode: Very long delays (5s+), no MTU, single discovery attempt
  ///
  /// Follows Android BluetoothGattClientManager pattern:
  /// connect -> delay -> MTU -> delay -> discover -> delay -> setNotify -> delay -> ready
  Future<void> _connectToDevice(Peripheral peripheral) async {
    final deviceUuid = peripheral.uuid.toString();
    final isDarwin = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final useSuperSlowMode = _superSlowModeDevices.contains(deviceUuid);
    final useSlowMode = _slowModeDevices.contains(deviceUuid) || useSuperSlowMode;

    if (isDarwin) {
      final mode = useSuperSlowMode ? 'SUPER_SLOW' : useSlowMode ? 'SLOW' : 'FAST';
      debugPrint('$_tag [Darwin] Connection mode: $mode for $deviceUuid');
    }

    // Step 1: Connect with timeout
    await _central.connect(peripheral).timeout(
          _connectionTimeout,
          onTimeout: () => throw TimeoutException(
              'Connection timed out after ${_connectionTimeout.inSeconds}s'),
        );

    _connectedDevices[deviceUuid] = peripheral;
    debugPrint('$_tag Connected to $deviceUuid');

    // Step 2: For Darwin FAST mode, try service discovery IMMEDIATELY
    // The goal is to complete discovery before PHY negotiation causes instability
    if (isDarwin && !useSlowMode) {
      debugPrint('$_tag [Darwin] FAST mode: Attempting immediate service discovery for $deviceUuid');
      final fastServices = await _attemptFastServiceDiscovery(peripheral);
      if (fastServices != null && fastServices.isNotEmpty) {
        debugPrint('$_tag [Darwin] FAST mode SUCCESS: Found ${fastServices.length} services');
        await _completeConnectionSetup(peripheral, fastServices);
        return;
      }
      // Fast mode failed - mark for slow mode on next connection
      debugPrint('$_tag [Darwin] FAST mode FAILED for $deviceUuid - will use SLOW mode on reconnect');
      _slowModeDevices.add(deviceUuid);
      // Disconnect and throw to trigger reconnection
      try {
        await _central.disconnect(peripheral);
      } catch (_) {}
      _connectedDevices.remove(deviceUuid);
      throw Exception('Fast service discovery failed, reconnecting with slow mode');
    }

    // Step 3: Slow/Super-Slow mode - longer delays for stability
    final Duration postConnectDelay;
    if (isDarwin && useSuperSlowMode) {
      postConnectDelay = const Duration(milliseconds: 5000); // Super slow: 5s delay
      debugPrint('$_tag [Darwin] SUPER_SLOW mode: 5s post-connect delay for $deviceUuid');
    } else if (isDarwin && useSlowMode) {
      postConnectDelay = const Duration(milliseconds: 3000); // Slow: 3s delay
      debugPrint('$_tag [Darwin] SLOW mode: 3s post-connect delay for $deviceUuid');
    } else if (isDarwin) {
      postConnectDelay = const Duration(milliseconds: 500);
    } else {
      postConnectDelay = _operationDelay;
    }
    debugPrint('$_tag Post-connect delay: ${postConnectDelay.inMilliseconds}ms for $deviceUuid');
    await Future.delayed(postConnectDelay);

    // CRITICAL: Verify connection still valid after delay
    // Connection can drop during the delay, especially on unstable BLE links
    if (!_connectedDevices.containsKey(deviceUuid)) {
      debugPrint('$_tag Connection dropped during post-connect delay for $deviceUuid');
      // DARWIN: Escalate to super slow mode if slow mode fails
      if (isDarwin && useSlowMode && !useSuperSlowMode) {
        debugPrint('$_tag [Darwin] SLOW mode connection dropped - escalating to SUPER_SLOW');
        _superSlowModeDevices.add(deviceUuid);
      }
      throw Exception('Connection dropped during setup delay');
    }

    // Step 4: MTU Negotiation (skip in Darwin slow/super-slow mode to reduce instability)
    if (AppConstants.requestMtu && !(isDarwin && useSlowMode)) {
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
    } else if (isDarwin && useSlowMode) {
      debugPrint('$_tag [Darwin] ${useSuperSlowMode ? "SUPER_SLOW" : "SLOW"} mode: Skipping MTU negotiation for stability');
    } else {
      debugPrint('$_tag MTU negotiation disabled for $deviceUuid');
    }

    // Step 5: Discover GATT services (with retry for flaky connections)
    List<GATTService> services = [];
    const maxDiscoveryRetries = 3;
    for (int attempt = 1; attempt <= maxDiscoveryRetries; attempt++) {
      // Check connection still valid before each attempt
      if (!_connectedDevices.containsKey(deviceUuid)) {
        debugPrint('$_tag Connection lost before discovery attempt $attempt for $deviceUuid');
        throw Exception('Connection lost before service discovery');
      }

      debugPrint(
          '$_tag Discovering GATT services for $deviceUuid (attempt $attempt/$maxDiscoveryRetries)');
      debugPrint('$_tag >>> Calling discoverGATT at ${DateTime.now()}');
      try {
        services = await _central.discoverGATT(peripheral).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('$_tag !!! discoverGATT TIMEOUT after 10s for $deviceUuid');
            return <GATTService>[];
          },
        );
        debugPrint('$_tag <<< discoverGATT returned at ${DateTime.now()} with ${services.length} services');
      } catch (e) {
        debugPrint('$_tag !!! discoverGATT EXCEPTION: $e');
        // Any exception during discovery likely means connection issue
        _connectedDevices.remove(deviceUuid);
        throw Exception('Service discovery failed: $e');
      }
      debugPrint('$_tag Found ${services.length} services on $deviceUuid');

      if (services.isNotEmpty) break;

      // Retry with delay if no services found (only if still connected)
      if (attempt < maxDiscoveryRetries) {
        debugPrint('$_tag No services found, retrying after delay...');
        await Future.delayed(const Duration(milliseconds: 1000));
        // Connection might drop during delay
        if (!_connectedDevices.containsKey(deviceUuid)) {
          debugPrint('$_tag Connection dropped during retry delay for $deviceUuid');
          throw Exception('Connection dropped during service discovery retry');
        }
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

  /// Attempts fast service discovery (minimal delay) for Darwin.
  /// Returns services if successful, null if failed.
  /// This tries to complete discovery before PHY negotiation causes instability.
  Future<List<GATTService>?> _attemptFastServiceDiscovery(Peripheral peripheral) async {
    final deviceUuid = peripheral.uuid.toString();

    // Very short delay - just enough for connection to establish
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      debugPrint('$_tag Fast discovery: Calling discoverGATT immediately for $deviceUuid');
      final services = await _central.discoverGATT(peripheral).timeout(
        const Duration(seconds: 5), // Shorter timeout for fast mode
        onTimeout: () {
          debugPrint('$_tag Fast discovery: TIMEOUT for $deviceUuid');
          return <GATTService>[];
        },
      );

      if (services.isNotEmpty) {
        debugPrint('$_tag Fast discovery: SUCCESS - found ${services.length} services for $deviceUuid');
        return services;
      }
      debugPrint('$_tag Fast discovery: No services found for $deviceUuid');
      return null;
    } catch (e) {
      debugPrint('$_tag Fast discovery: FAILED for $deviceUuid - $e');
      return null;
    }
  }

  /// Completes connection setup after services have been discovered.
  /// Used by fast mode to finish setup after successful immediate discovery.
  Future<void> _completeConnectionSetup(Peripheral peripheral, List<GATTService> services) async {
    final deviceUuid = peripheral.uuid.toString();

    // Verify connection still valid
    if (!_connectedDevices.containsKey(deviceUuid)) {
      throw Exception('Connection lost before setup completion');
    }

    // Find our mesh service and characteristic
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

    // Minimal delay before notifications
    await Future.delayed(const Duration(milliseconds: 50));

    // Check connection still valid before notifications
    if (!_connectedDevices.containsKey(deviceUuid)) {
      throw Exception('Connection lost before enabling notifications');
    }

    // Enable notifications (with single attempt for fast mode, don't retry aggressively)
    bool notificationsEnabled = false;
    try {
      debugPrint('$_tag Enabling notifications for $deviceUuid (single attempt)');
      await _central
          .setCharacteristicNotifyState(
            peripheral,
            meshCharacteristic,
            state: true,
          )
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('setNotifyState timed out'),
          );
      notificationsEnabled = true;
      debugPrint('$_tag Notifications enabled for $deviceUuid');
    } catch (e) {
      debugPrint('$_tag Failed to enable notifications on $deviceUuid: $e');
      // Check if connection is still valid - if not, throw
      if (!_connectedDevices.containsKey(deviceUuid)) {
        throw Exception('Connection lost during notification setup');
      }
      // Continue anyway - we might still be able to write to the device
    }

    // Final connection check
    if (!_connectedDevices.containsKey(deviceUuid)) {
      throw Exception('Connection lost after setup');
    }

    // Notify delegate - connection complete
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
    debugPrint('$_tag *** NOTIFICATION RECEIVED from $deviceUuid: ${value.length} bytes ***');

    final packet = BitchatPacket.decode(value);

    if (packet != null) {
      debugPrint('$_tag Decoded packet successfully from $deviceUuid');
      delegate?.onPacketReceived(packet, deviceUuid, peripheral);
    } else {
      debugPrint(
          '$_tag Failed to decode packet from $deviceUuid (${value.length} bytes) - may need reassembly');
      debugPrint('$_tag   First bytes: ${value.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
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
    final isDarwin = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return {
      'isActive': _isActive,
      'platform': isDarwin ? 'Darwin' : 'Other',
      'connectedDevices': _connectedDevices.keys.toList(),
      'connectingDevices': _connectingDevices.toList(),
      'connectionAttempts': Map.from(_connectionAttempts),
      'cachedCharacteristics': _meshCharacteristics.keys.toList(),
      'slowModeDevices': _slowModeDevices.toList(),
      if (isDarwin) 'superSlowModeDevices': _superSlowModeDevices.toList(),
      if (isDarwin) 'consecutiveFailures': Map.from(_consecutiveFailures),
    };
  }

  /// Reset slow mode for all devices (useful after app restart or network change).
  /// Devices in slow mode will retry with fast mode on next connection.
  void resetAllSlowModes() {
    final slowCount = _slowModeDevices.length;
    final superSlowCount = _superSlowModeDevices.length;
    _slowModeDevices.clear();
    _superSlowModeDevices.clear();
    _consecutiveFailures.clear();
    if (slowCount > 0 || superSlowCount > 0) {
      debugPrint('$_tag Reset slow mode for $slowCount devices, super-slow for $superSlowCount devices');
    }
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
