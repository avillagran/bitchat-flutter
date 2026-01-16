import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Battery percentage thresholds
class BatteryThresholds {
  static const int critical = 10;
  static const int low = 20;
  static const int medium = 50;

  static bool isCritical(int level) => level <= critical;
  static bool isLow(int level) => level <= low && level > critical;
  static bool isMedium(int level) => level <= medium && level > low;
  static bool isNormal(int level) => level > medium;
}

/// Power mode for adaptive behavior
enum PowerMode {
  /// Full power, no restrictions (charging or high battery + foreground)
  performance,

  /// Moderate power saving (normal battery level)
  balanced,

  /// Aggressive power saving (low battery)
  powerSaver,

  /// Minimal operations only (critical battery)
  ultraLowPower,
}

/// Power state information
class PowerState {
  final int? batteryLevel;
  final bool isCharging;
  final bool isPowerSaveMode;
  final String platform;
  final PowerMode powerMode;
  final DateTime timestamp;

  const PowerState({
    required this.batteryLevel,
    required this.isCharging,
    required this.isPowerSaveMode,
    required this.platform,
    required this.powerMode,
    required this.timestamp,
  });

  PowerState copyWith({
    int? batteryLevel,
    bool? isCharging,
    bool? isPowerSaveMode,
    String? platform,
    PowerMode? powerMode,
    DateTime? timestamp,
  }) {
    return PowerState(
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isCharging: isCharging ?? this.isCharging,
      isPowerSaveMode: isPowerSaveMode ?? this.isPowerSaveMode,
      platform: platform ?? this.platform,
      powerMode: powerMode ?? this.powerMode,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'PowerState(batteryLevel: $batteryLevel%, isCharging: $isCharging, '
        'isPowerSaveMode: $isPowerSaveMode, powerMode: $powerMode, '
        'platform: $platform)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PowerState &&
        other.batteryLevel == batteryLevel &&
        other.isCharging == isCharging &&
        other.isPowerSaveMode == isPowerSaveMode &&
        other.powerMode == powerMode &&
        other.platform == platform;
  }

  @override
  int get hashCode =>
      Object.hash(batteryLevel, isCharging, isPowerSaveMode, powerMode, platform);
}

/// Scan duty cycle configuration
class ScanDutyCycle {
  final Duration onDuration;
  final Duration offDuration;

  const ScanDutyCycle({
    required this.onDuration,
    required this.offDuration,
  });

  static const normal = ScanDutyCycle(
    onDuration: Duration(seconds: 8),
    offDuration: Duration(seconds: 2),
  );

  static const powerSaver = ScanDutyCycle(
    onDuration: Duration(seconds: 2),
    offDuration: Duration(seconds: 28),
  );

  static const ultraLowPower = ScanDutyCycle(
    onDuration: Duration(seconds: 1),
    offDuration: Duration(seconds: 29),
  );

  static const continuous = ScanDutyCycle(
    onDuration: Duration(hours: 1),
    offDuration: Duration.zero,
  );
}

/// Connection limits per power mode
class ConnectionLimits {
  final int maxConnections;
  final int rssiThreshold;

  const ConnectionLimits({
    required this.maxConnections,
    required this.rssiThreshold,
  });

  static const performance = ConnectionLimits(
    maxConnections: 8,
    rssiThreshold: -95,
  );

  static const balanced = ConnectionLimits(
    maxConnections: 8,
    rssiThreshold: -85,
  );

  static const powerSaver = ConnectionLimits(
    maxConnections: 8,
    rssiThreshold: -75,
  );

  static const ultraLowPower = ConnectionLimits(
    maxConnections: 4,
    rssiThreshold: -65,
  );
}

/// Power-aware message frequency configuration
class MessageFrequency {
  final Duration interval;
  final int burstLimit;

  const MessageFrequency({
    required this.interval,
    required this.burstLimit,
  });

  static const performance = MessageFrequency(
    interval: Duration(milliseconds: 100),
    burstLimit: 50,
  );

  static const balanced = MessageFrequency(
    interval: Duration(milliseconds: 250),
    burstLimit: 20,
  );

  static const powerSaver = MessageFrequency(
    interval: Duration(milliseconds: 500),
    burstLimit: 10,
  );

  static const ultraLowPower = MessageFrequency(
    interval: Duration(seconds: 1),
    burstLimit: 5,
  );
}

/// Power-aware Bluetooth management for bitchat
/// Adjusts scanning, advertising, and connection behavior based on battery state
/// Implements adaptive scanning and power-aware message frequency
class PowerManager extends ChangeNotifier {
  static const String _tag = 'PowerManager';

  PowerState _currentState;
  Timer? _batteryMonitorTimer;
  Timer? _dutyCycleTimer;
  bool _isScanning = false;
  bool _isAppInBackground = false;

  final List<void Function(PowerState)> _listeners = [];
  final List<void Function(bool)> _scanStateListeners = [];

  /// Constructor. Initializes the state with default values
  PowerManager({PowerState? initialState})
      : _currentState = initialState ??
            PowerState(
              batteryLevel: null,
              isCharging: false,
              isPowerSaveMode: false,
              platform: _detectPlatform(),
              powerMode: PowerMode.balanced,
              timestamp: DateTime.now(),
            ) {
    _startBatteryMonitoring();
  }

  /// Get current power state
  PowerState get currentState => _currentState;

  /// Get current power mode
  PowerMode get powerMode => _currentState.powerMode;

  /// Get battery level (0-100), null if unavailable
  int? get batteryLevel => _currentState.batteryLevel;

  /// Check if device is charging
  bool get isCharging => _currentState.isCharging;

  /// Check if power save mode is enabled
  bool get isPowerSaveMode => _currentState.isPowerSaveMode;

  /// Check if device is in background
  bool get isAppInBackground => _isAppInBackground;

  /// Detect current platform
  static String _detectPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  /// Start battery monitoring (periodic updates)
  void _startBatteryMonitoring() {
    // Update battery state immediately
    _updateBatteryState();

    // Schedule periodic updates
    _batteryMonitorTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateBatteryState(),
    );
  }

  /// Update battery state from platform
  Future<void> _updateBatteryState() async {
    // TODO: Implement native battery monitoring via MethodChannel
    // For now, simulate battery changes for testing
    // Don't update if we don't have a battery level yet
    final batteryLevel = _currentState.batteryLevel;
    if (batteryLevel == null) {
      return;
    }
    final isCharging = _currentState.isCharging;

    // Update power mode based on battery state
    final newMode = _calculatePowerMode(batteryLevel, isCharging);

    // Update state if changed
    if (newMode != _currentState.powerMode ||
        _currentState.batteryLevel != batteryLevel) {
      _currentState = _currentState.copyWith(
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        powerMode: newMode,
        timestamp: DateTime.now(),
      );

      _notifyPowerStateChanged();

      // Restart duty cycle if power mode changed
      if (newMode != _currentState.powerMode) {
        _restartDutyCycle();
      }
    }
  }

  /// Calculate power mode based on battery level and charging state
  PowerMode _calculatePowerMode(int batteryLevel, bool isCharging) {
    // Critical battery: Ultra low power regardless of other factors
    // This overrides charging and foreground state
    if (BatteryThresholds.isCritical(batteryLevel)) {
      return PowerMode.ultraLowPower;
    }

    // Performance mode: Charging and in foreground
    if (isCharging && !_isAppInBackground) {
      return PowerMode.performance;
    }

    // Low battery: Power saver
    if (BatteryThresholds.isLow(batteryLevel)) {
      return PowerMode.powerSaver;
    }

    // Medium battery: Balanced (or power saver if in background)
    if (BatteryThresholds.isMedium(batteryLevel)) {
      return _isAppInBackground ? PowerMode.powerSaver : PowerMode.balanced;
    }

    // Normal battery: Balanced (or power saver if in background)
    return _isAppInBackground ? PowerMode.powerSaver : PowerMode.balanced;
  }

  /// Notify listeners of power state change
  void _notifyPowerStateChanged() {
    notifyListeners();
    for (final listener in List.of(_listeners)) {
      try {
        listener(_currentState);
      } catch (e) {
        debugPrint('$_tag: Error notifying power state listener: $e');
      }
    }
  }

  /// Notify listeners of scan state change
  void _notifyScanStateChanged(bool scanning) {
    _isScanning = scanning;
    for (final listener in List.of(_scanStateListeners)) {
      try {
        listener(scanning);
      } catch (e) {
        debugPrint('$_tag: Error notifying scan state listener: $e');
      }
    }
  }

  /// Set app background state
  void setAppInBackground(bool inBackground) {
    if (_isAppInBackground != inBackground) {
      _isAppInBackground = inBackground;
      debugPrint('$_tag: App in background changed to $inBackground');
      _updateBatteryState();
    }
  }

  /// Update power state (for testing or manual override)
  @visibleForTesting
  void updatePowerState({
    int? batteryLevel,
    bool? isCharging,
    bool? isPowerSaveMode,
  }) {
    final newBatteryLevel = batteryLevel ?? _currentState.batteryLevel;
    final newCharging = isCharging ?? _currentState.isCharging;
    final newPowerSaveMode = isPowerSaveMode ?? _currentState.isPowerSaveMode;

    final newMode = _calculatePowerMode(
      newBatteryLevel ?? 100,
      newCharging,
    );

    _currentState = _currentState.copyWith(
      batteryLevel: newBatteryLevel,
      isCharging: newCharging,
      isPowerSaveMode: newPowerSaveMode,
      powerMode: newMode,
      timestamp: DateTime.now(),
    );

    _notifyPowerStateChanged();
    _restartDutyCycle();
  }

  /// Get scan duty cycle for current power mode
  ScanDutyCycle getScanDutyCycle() {
    switch (_currentState.powerMode) {
      case PowerMode.performance:
        return ScanDutyCycle.continuous;
      case PowerMode.balanced:
        return ScanDutyCycle.normal;
      case PowerMode.powerSaver:
        return ScanDutyCycle.powerSaver;
      case PowerMode.ultraLowPower:
        return ScanDutyCycle.ultraLowPower;
    }
  }

  /// Get connection limits for current power mode
  ConnectionLimits getConnectionLimits() {
    switch (_currentState.powerMode) {
      case PowerMode.performance:
        return ConnectionLimits.performance;
      case PowerMode.balanced:
        return ConnectionLimits.balanced;
      case PowerMode.powerSaver:
        return ConnectionLimits.powerSaver;
      case PowerMode.ultraLowPower:
        return ConnectionLimits.ultraLowPower;
    }
  }

  /// Get message frequency configuration for current power mode
  MessageFrequency getMessageFrequency() {
    switch (_currentState.powerMode) {
      case PowerMode.performance:
        return MessageFrequency.performance;
      case PowerMode.balanced:
        return MessageFrequency.balanced;
      case PowerMode.powerSaver:
        return MessageFrequency.powerSaver;
      case PowerMode.ultraLowPower:
        return MessageFrequency.ultraLowPower;
    }
  }

  /// Check if duty cycling should be used
  bool shouldUseDutyCycle() {
    return _currentState.powerMode != PowerMode.performance;
  }

  /// Start adaptive scanning with duty cycle
  void startAdaptiveScanning() {
    _restartDutyCycle();
    debugPrint('$_tag: Started adaptive scanning');
  }

  /// Stop adaptive scanning
  void stopAdaptiveScanning() {
    _dutyCycleTimer?.cancel();
    _dutyCycleTimer = null;
    _notifyScanStateChanged(false);
    debugPrint('$_tag: Stopped adaptive scanning');
  }

  /// Restart duty cycle with new power mode parameters
  void _restartDutyCycle() {
    _dutyCycleTimer?.cancel();
    _dutyCycleTimer = null;

    if (!shouldUseDutyCycle()) {
      // Performance mode: always scan
      _notifyScanStateChanged(true);
      return;
    }

    final dutyCycle = getScanDutyCycle();
    _runDutyCycle(dutyCycle);
  }

  /// Run duty cycle loop
  void _runDutyCycle(ScanDutyCycle dutyCycle) {
    if (_dutyCycleTimer != null) return;

    debugPrint(
      '$_tag: Starting duty cycle: ON for ${dutyCycle.onDuration.inSeconds}s, '
      'OFF for ${dutyCycle.offDuration.inSeconds}s',
    );

    // Scan ON
    _notifyScanStateChanged(true);

    _dutyCycleTimer = Timer(dutyCycle.onDuration, () {
      // Scan OFF
      _notifyScanStateChanged(false);

      // Schedule next ON period
      _dutyCycleTimer = Timer(dutyCycle.offDuration, () {
        _dutyCycleTimer = null;
        if (shouldUseDutyCycle()) {
          _runDutyCycle(getScanDutyCycle());
        }
      });
    });
  }

  /// Add a power state listener
  void addPowerStateListener(void Function(PowerState) listener) {
    _listeners.add(listener);
  }

  /// Remove a power state listener
  void removePowerStateListener(void Function(PowerState) listener) {
    _listeners.remove(listener);
  }

  /// Add a scan state listener
  void addScanStateListener(void Function(bool) listener) {
    _scanStateListeners.add(listener);
  }

  /// Remove a scan state listener
  void removeScanStateListener(void Function(bool) listener) {
    _scanStateListeners.remove(listener);
  }

  /// Check if scanning is currently active
  bool get isScanning => _isScanning;

  /// Get diagnostic information
  String getDiagnostics() {
    final buffer = StringBuffer();
    buffer.writeln('=== Power Manager Diagnostics ===');
    buffer.writeln('Platform: ${_currentState.platform}');
    buffer.writeln('Power Mode: ${_currentState.powerMode}');
    buffer.writeln('Battery Level: ${_currentState.batteryLevel ?? "Unknown"}%');
    buffer.writeln('Is Charging: ${_currentState.isCharging}');
    buffer.writeln('Power Save Mode: ${_currentState.isPowerSaveMode}');
    buffer.writeln('App In Background: $_isAppInBackground');
    buffer.writeln('Current Time: ${_currentState.timestamp}');
    buffer.writeln();

    final limits = getConnectionLimits();
    buffer.writeln('Connection Limits:');
    buffer.writeln('  Max Connections: ${limits.maxConnections}');
    buffer.writeln('  RSSI Threshold: ${limits.rssiThreshold} dBm');
    buffer.writeln();

    final messageFreq = getMessageFrequency();
    buffer.writeln('Message Frequency:');
    buffer.writeln('  Interval: ${messageFreq.interval.inMilliseconds}ms');
    buffer.writeln('  Burst Limit: ${messageFreq.burstLimit}');
    buffer.writeln();

    final dutyCycle = getScanDutyCycle();
    buffer.writeln('Scan Duty Cycle:');
    buffer.writeln('  Use Duty Cycle: ${shouldUseDutyCycle()}');
    buffer.writeln('  On Duration: ${dutyCycle.onDuration.inSeconds}s');
    buffer.writeln('  Off Duration: ${dutyCycle.offDuration.inSeconds}s');
    buffer.writeln('  Currently Scanning: $_isScanning');
    buffer.writeln();

    buffer.writeln('Listeners:');
    buffer.writeln('  Power State: ${_listeners.length}');
    buffer.writeln('  Scan State: ${_scanStateListeners.length}');

    return buffer.toString();
  }

  /// Log diagnostic information
  void logDiagnostics() {
    debugPrint(getDiagnostics());
  }

  /// Clean up resources
  @override
  void dispose() {
    _batteryMonitorTimer?.cancel();
    _dutyCycleTimer?.cancel();
    _listeners.clear();
    _scanStateListeners.clear();
    super.dispose();
  }
}
