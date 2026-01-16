import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitchat/features/mesh/ble_manager.dart';

/// Debug message types for the console.
enum DebugMessageType { system, peer, packet, relay, error }

/// A debug log message.
class DebugMessage {
  final DateTime timestamp;
  final DebugMessageType type;
  final String message;
  final String? details;

  const DebugMessage({
    required this.timestamp,
    required this.type,
    required this.message,
    this.details,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// A BLE scan result for debug display.
class DebugScanResult {
  final String deviceName;
  final String deviceAddress;
  final int rssi;
  final String? peerID;
  final DateTime timestamp;

  const DebugScanResult({
    required this.deviceName,
    required this.deviceAddress,
    required this.rssi,
    this.peerID,
    required this.timestamp,
  });
}

/// Connection type enum.
enum ConnectionType { gattServer, gattClient }

/// A connected device for debug display.
class ConnectedDevice {
  final String deviceAddress;
  final String? peerID;
  final String? nickname;
  final int? rssi;
  final ConnectionType connectionType;
  final bool isDirectConnection;

  const ConnectedDevice({
    required this.deviceAddress,
    this.peerID,
    this.nickname,
    this.rssi,
    required this.connectionType,
    this.isDirectConnection = true,
  });
}

/// Packet relay statistics.
class PacketRelayStats {
  final int incomingTotal;
  final int outgoingTotal;
  final double incomingPerSecond;
  final double outgoingPerSecond;
  final double incomingPerMinute;
  final double outgoingPerMinute;

  /// Time series data for graphs (last 60 seconds)
  final List<int> incomingSeries;
  final List<int> outgoingSeries;

  const PacketRelayStats({
    this.incomingTotal = 0,
    this.outgoingTotal = 0,
    this.incomingPerSecond = 0,
    this.outgoingPerSecond = 0,
    this.incomingPerMinute = 0,
    this.outgoingPerMinute = 0,
    this.incomingSeries = const [],
    this.outgoingSeries = const [],
  });

  PacketRelayStats copyWith({
    int? incomingTotal,
    int? outgoingTotal,
    double? incomingPerSecond,
    double? outgoingPerSecond,
    double? incomingPerMinute,
    double? outgoingPerMinute,
    List<int>? incomingSeries,
    List<int>? outgoingSeries,
  }) {
    return PacketRelayStats(
      incomingTotal: incomingTotal ?? this.incomingTotal,
      outgoingTotal: outgoingTotal ?? this.outgoingTotal,
      incomingPerSecond: incomingPerSecond ?? this.incomingPerSecond,
      outgoingPerSecond: outgoingPerSecond ?? this.outgoingPerSecond,
      incomingPerMinute: incomingPerMinute ?? this.incomingPerMinute,
      outgoingPerMinute: outgoingPerMinute ?? this.outgoingPerMinute,
      incomingSeries: incomingSeries ?? this.incomingSeries,
      outgoingSeries: outgoingSeries ?? this.outgoingSeries,
    );
  }
}

/// Graph display mode for packet relay stats.
enum GraphMode { overall, perDevice, perPeer }

/// Debug settings state.
class DebugSettingsState {
  // Toggles
  final bool verboseLoggingEnabled;
  final bool gattServerEnabled;
  final bool gattClientEnabled;
  final bool packetRelayEnabled;
  final bool requestMtuEnabled;

  // Slider values
  final int maxConnectionsOverall;
  final int maxServerConnections;
  final int maxClientConnections;
  final int requestedMtuSize;

  // Sync settings
  final int seenPacketCapacity;
  final int gcsMaxBytes;
  final double gcsFprPercent;

  // Runtime data (not persisted)
  final List<DebugMessage> debugMessages;
  final List<DebugScanResult> scanResults;
  final List<ConnectedDevice> connectedDevices;
  final PacketRelayStats relayStats;

  // Graph mode for relay stats display
  final GraphMode graphMode;

  const DebugSettingsState({
    this.verboseLoggingEnabled = false,
    this.gattServerEnabled = true,
    this.gattClientEnabled = true,
    this.packetRelayEnabled = true,
    this.requestMtuEnabled = false,
    this.maxConnectionsOverall = 8,
    this.maxServerConnections = 8,
    this.maxClientConnections = 8,
    this.requestedMtuSize = 247,
    this.seenPacketCapacity = 500,
    this.gcsMaxBytes = 400,
    this.gcsFprPercent = 1.0,
    this.debugMessages = const [],
    this.scanResults = const [],
    this.connectedDevices = const [],
    this.relayStats = const PacketRelayStats(),
    this.graphMode = GraphMode.overall,
  });

  DebugSettingsState copyWith({
    bool? verboseLoggingEnabled,
    bool? gattServerEnabled,
    bool? gattClientEnabled,
    bool? packetRelayEnabled,
    bool? requestMtuEnabled,
    int? maxConnectionsOverall,
    int? maxServerConnections,
    int? maxClientConnections,
    int? requestedMtuSize,
    int? seenPacketCapacity,
    int? gcsMaxBytes,
    double? gcsFprPercent,
    List<DebugMessage>? debugMessages,
    List<DebugScanResult>? scanResults,
    List<ConnectedDevice>? connectedDevices,
    PacketRelayStats? relayStats,
    GraphMode? graphMode,
  }) {
    return DebugSettingsState(
      verboseLoggingEnabled:
          verboseLoggingEnabled ?? this.verboseLoggingEnabled,
      gattServerEnabled: gattServerEnabled ?? this.gattServerEnabled,
      gattClientEnabled: gattClientEnabled ?? this.gattClientEnabled,
      packetRelayEnabled: packetRelayEnabled ?? this.packetRelayEnabled,
      requestMtuEnabled: requestMtuEnabled ?? this.requestMtuEnabled,
      maxConnectionsOverall:
          maxConnectionsOverall ?? this.maxConnectionsOverall,
      maxServerConnections: maxServerConnections ?? this.maxServerConnections,
      maxClientConnections: maxClientConnections ?? this.maxClientConnections,
      requestedMtuSize: requestedMtuSize ?? this.requestedMtuSize,
      seenPacketCapacity: seenPacketCapacity ?? this.seenPacketCapacity,
      gcsMaxBytes: gcsMaxBytes ?? this.gcsMaxBytes,
      gcsFprPercent: gcsFprPercent ?? this.gcsFprPercent,
      debugMessages: debugMessages ?? this.debugMessages,
      scanResults: scanResults ?? this.scanResults,
      connectedDevices: connectedDevices ?? this.connectedDevices,
      relayStats: relayStats ?? this.relayStats,
      graphMode: graphMode ?? this.graphMode,
    );
  }
}

/// Debug settings notifier - manages debug state and persistence.
class DebugSettingsNotifier extends StateNotifier<DebugSettingsState> {
  static const int _maxDebugMessages = 100;
  static const int _maxScanResults = 50;

  // Preference keys
  static const String _keyVerboseLogging = 'debug_verbose_logging';
  static const String _keyGattServer = 'debug_gatt_server';
  static const String _keyGattClient = 'debug_gatt_client';
  static const String _keyPacketRelay = 'debug_packet_relay';
  static const String _keyRequestMtu = 'debug_request_mtu';
  static const String _keyMaxConnOverall = 'debug_max_conn_overall';
  static const String _keyMaxConnServer = 'debug_max_conn_server';
  static const String _keyMaxConnClient = 'debug_max_conn_client';
  static const String _keyMtuSize = 'debug_mtu_size';
  static const String _keySeenPacketCapacity = 'debug_seen_packet_capacity';
  static const String _keyGcsMaxBytes = 'debug_gcs_max_bytes';
  static const String _keyGcsFprPercent = 'debug_gcs_fpr_percent';

  SharedPreferences? _prefs;
  StreamSubscription<DiscoveredEventArgs>? _scanSubscription;

  DebugSettingsNotifier() : super(const DebugSettingsState()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs();
    _startScanListener();
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;

    state = state.copyWith(
      verboseLoggingEnabled: _prefs!.getBool(_keyVerboseLogging) ?? false,
      gattServerEnabled: _prefs!.getBool(_keyGattServer) ?? true,
      gattClientEnabled: _prefs!.getBool(_keyGattClient) ?? true,
      packetRelayEnabled: _prefs!.getBool(_keyPacketRelay) ?? true,
      requestMtuEnabled: _prefs!.getBool(_keyRequestMtu) ?? false,
      maxConnectionsOverall: _prefs!.getInt(_keyMaxConnOverall) ?? 8,
      maxServerConnections: _prefs!.getInt(_keyMaxConnServer) ?? 8,
      maxClientConnections: _prefs!.getInt(_keyMaxConnClient) ?? 8,
      requestedMtuSize: _prefs!.getInt(_keyMtuSize) ?? 247,
      seenPacketCapacity: _prefs!.getInt(_keySeenPacketCapacity) ?? 500,
      gcsMaxBytes: _prefs!.getInt(_keyGcsMaxBytes) ?? 400,
      gcsFprPercent: _prefs!.getDouble(_keyGcsFprPercent) ?? 1.0,
    );

    _log(DebugMessageType.system, 'Debug settings loaded from preferences');
  }

  void _startScanListener() {
    // Only start listening if BleManager is initialized and supports central
    if (!BleManager.instance.isInitialized) {
      debugPrint(
          '[DebugSettings] BleManager not initialized, skipping scan listener');
      return;
    }

    if (!BleManager.instance.supportsCentral) {
      debugPrint(
          '[DebugSettings] Central role not supported, skipping scan listener');
      return;
    }

    _scanSubscription = BleManager.instance.central.discovered.listen((event) {
      final deviceName = event.advertisement.name?.isNotEmpty == true
          ? event.advertisement.name!
          : 'Unknown';
      final deviceAddress = event.peripheral.uuid.toString();

      _addScanResult(DebugScanResult(
        deviceName: deviceName,
        deviceAddress: deviceAddress,
        rssi: event.rssi,
        peerID: null, // Will be populated after connection
        timestamp: DateTime.now(),
      ));
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  // --- Toggle methods ---

  void setVerboseLogging(bool value) {
    state = state.copyWith(verboseLoggingEnabled: value);
    _prefs?.setBool(_keyVerboseLogging, value);
    _log(DebugMessageType.system,
        'Verbose logging ${value ? 'enabled' : 'disabled'}');
  }

  void setGattServerEnabled(bool value) {
    state = state.copyWith(gattServerEnabled: value);
    _prefs?.setBool(_keyGattServer, value);
    _log(DebugMessageType.system,
        'GATT Server ${value ? 'enabled' : 'disabled'}');
  }

  void setGattClientEnabled(bool value) {
    state = state.copyWith(gattClientEnabled: value);
    _prefs?.setBool(_keyGattClient, value);
    _log(DebugMessageType.system,
        'GATT Client ${value ? 'enabled' : 'disabled'}');
  }

  void setPacketRelayEnabled(bool value) {
    state = state.copyWith(packetRelayEnabled: value);
    _prefs?.setBool(_keyPacketRelay, value);
    _log(DebugMessageType.system,
        'Packet relay ${value ? 'enabled' : 'disabled'}');
  }

  void setRequestMtuEnabled(bool value) {
    state = state.copyWith(requestMtuEnabled: value);
    _prefs?.setBool(_keyRequestMtu, value);
    _log(DebugMessageType.system,
        'MTU request ${value ? 'enabled' : 'disabled'}');
  }

  // --- Slider methods ---

  void setMaxConnectionsOverall(int value) {
    final clamped = value.clamp(1, 32);
    state = state.copyWith(maxConnectionsOverall: clamped);
    _prefs?.setInt(_keyMaxConnOverall, clamped);
  }

  void setMaxServerConnections(int value) {
    final clamped = value.clamp(1, 32);
    state = state.copyWith(maxServerConnections: clamped);
    _prefs?.setInt(_keyMaxConnServer, clamped);
  }

  void setMaxClientConnections(int value) {
    final clamped = value.clamp(1, 32);
    state = state.copyWith(maxClientConnections: clamped);
    _prefs?.setInt(_keyMaxConnClient, clamped);
  }

  void setRequestedMtuSize(int value) {
    final clamped = value.clamp(23, 517);
    state = state.copyWith(requestedMtuSize: clamped);
    _prefs?.setInt(_keyMtuSize, clamped);
    _log(DebugMessageType.system, 'MTU size set to $clamped');
  }

  void setSeenPacketCapacity(int value) {
    final clamped = value.clamp(10, 1000);
    state = state.copyWith(seenPacketCapacity: clamped);
    _prefs?.setInt(_keySeenPacketCapacity, clamped);
  }

  void setGcsMaxBytes(int value) {
    final clamped = value.clamp(128, 1024);
    state = state.copyWith(gcsMaxBytes: clamped);
    _prefs?.setInt(_keyGcsMaxBytes, clamped);
  }

  void setGcsFprPercent(double value) {
    final clamped = value.clamp(0.1, 5.0);
    state = state.copyWith(gcsFprPercent: clamped);
    _prefs?.setDouble(_keyGcsFprPercent, clamped);
  }

  // --- Runtime data methods ---

  void _log(DebugMessageType type, String message, [String? details]) {
    final msg = DebugMessage(
      timestamp: DateTime.now(),
      type: type,
      message: message,
      details: details,
    );

    final messages = [msg, ...state.debugMessages];
    if (messages.length > _maxDebugMessages) {
      messages.removeLast();
    }

    state = state.copyWith(debugMessages: messages);

    if (state.verboseLoggingEnabled) {
      debugPrint('[Debug] ${msg.formattedTime} [${type.name}] $message');
    }
  }

  /// Public method to add a debug log entry.
  void log(DebugMessageType type, String message, [String? details]) {
    _log(type, message, details);
  }

  void _addScanResult(DebugScanResult result) {
    // Check for duplicate (same address within last 5 seconds)
    final isDuplicate = state.scanResults.any((r) =>
        r.deviceAddress == result.deviceAddress &&
        result.timestamp.difference(r.timestamp).inSeconds < 5);

    if (isDuplicate) return;

    final results = [result, ...state.scanResults];
    if (results.length > _maxScanResults) {
      results.removeLast();
    }

    state = state.copyWith(scanResults: results);
  }

  void addConnectedDevice(ConnectedDevice device) {
    // Remove existing entry with same address
    final devices = state.connectedDevices
        .where((d) => d.deviceAddress != device.deviceAddress)
        .toList();
    devices.insert(0, device);

    state = state.copyWith(connectedDevices: devices);
    _log(
      DebugMessageType.peer,
      'Device connected: ${device.deviceAddress}',
      'Type: ${device.connectionType.name}',
    );
  }

  void removeConnectedDevice(String deviceAddress) {
    final devices = state.connectedDevices
        .where((d) => d.deviceAddress != deviceAddress)
        .toList();

    state = state.copyWith(connectedDevices: devices);
    _log(DebugMessageType.peer, 'Device disconnected: $deviceAddress');
  }

  void updateRelayStats({
    int? incomingDelta,
    int? outgoingDelta,
  }) {
    final stats = state.relayStats;

    // Update time series (keep last 60 samples)
    final newIncomingSeries = List<int>.from(stats.incomingSeries);
    final newOutgoingSeries = List<int>.from(stats.outgoingSeries);

    if (incomingDelta != null && incomingDelta > 0) {
      newIncomingSeries.add(incomingDelta);
      if (newIncomingSeries.length > 60) {
        newIncomingSeries.removeAt(0);
      }
    }

    if (outgoingDelta != null && outgoingDelta > 0) {
      newOutgoingSeries.add(outgoingDelta);
      if (newOutgoingSeries.length > 60) {
        newOutgoingSeries.removeAt(0);
      }
    }

    state = state.copyWith(
      relayStats: stats.copyWith(
        incomingTotal: stats.incomingTotal + (incomingDelta ?? 0),
        outgoingTotal: stats.outgoingTotal + (outgoingDelta ?? 0),
        incomingSeries: newIncomingSeries,
        outgoingSeries: newOutgoingSeries,
      ),
    );
  }

  /// Sets the graph display mode.
  void setGraphMode(GraphMode mode) {
    state = state.copyWith(graphMode: mode);
  }

  void clearDebugMessages() {
    state = state.copyWith(debugMessages: []);
    _log(DebugMessageType.system, 'Debug console cleared');
  }

  void clearScanResults() {
    state = state.copyWith(scanResults: []);
  }

  /// Returns a debug info summary string.
  String getDebugSummary() {
    final s = state;
    return '''
Debug Settings Summary:
- Verbose Logging: ${s.verboseLoggingEnabled}
- GATT Server: ${s.gattServerEnabled}
- GATT Client: ${s.gattClientEnabled}
- Packet Relay: ${s.packetRelayEnabled}
- Request MTU: ${s.requestMtuEnabled} (size: ${s.requestedMtuSize})
- Max Connections: ${s.maxConnectionsOverall} (server: ${s.maxServerConnections}, client: ${s.maxClientConnections})
- Connected Devices: ${s.connectedDevices.length}
- Recent Scans: ${s.scanResults.length}
- Relay Stats: IN ${s.relayStats.incomingTotal} / OUT ${s.relayStats.outgoingTotal}
''';
  }
}

/// Provider for debug settings state.
final debugSettingsProvider =
    StateNotifierProvider<DebugSettingsNotifier, DebugSettingsState>((ref) {
  return DebugSettingsNotifier();
});
