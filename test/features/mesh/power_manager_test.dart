import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/mesh/power_manager.dart';

void main() {
  group('PowerManager', () {
    late PowerManager powerManager;

    setUp(() {
      powerManager = PowerManager();
    });

    tearDown(() {
      powerManager.dispose();
    });

    test('initial state/default values', () {
      final state = powerManager.currentState;
      expect(state.isCharging, isFalse);
      expect(state.isPowerSaveMode, isFalse);
      expect(state.batteryLevel, isNull);
      expect(powerManager.powerMode, PowerMode.balanced);
    });

    test('updatePowerState notifies listeners', () {
      var notified = false;
      powerManager.addListener(() => notified = true);
      powerManager.updatePowerState(
        batteryLevel: 99,
        isCharging: true,
      );
      expect(powerManager.batteryLevel, 99);
      expect(powerManager.isCharging, isTrue);
      expect(notified, isTrue);
    });

    test('add/remove PowerStateListener fires callback', () {
      PowerState? last;
      void cb(PowerState s) => last = s;
      powerManager.addPowerStateListener(cb);
      powerManager.updatePowerState(batteryLevel: 50, isCharging: false);
      expect(last, isNotNull);
      powerManager.removePowerStateListener(cb);
      last = null;
      powerManager.updatePowerState(batteryLevel: 40, isCharging: false);
      expect(last, isNull);
    });

    test('calculates power mode based on battery level', () {
      // Critical battery
      powerManager.updatePowerState(batteryLevel: 5, isCharging: false);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);

      // Low battery
      powerManager.updatePowerState(batteryLevel: 15, isCharging: false);
      expect(powerManager.powerMode, PowerMode.powerSaver);

      // Medium battery
      powerManager.updatePowerState(batteryLevel: 30, isCharging: false);
      expect(powerManager.powerMode, PowerMode.balanced);

      // Normal battery
      powerManager.updatePowerState(batteryLevel: 80, isCharging: false);
      expect(powerManager.powerMode, PowerMode.balanced);
    });

    test('performance mode when charging and in foreground', () {
      powerManager.setAppInBackground(false);
      powerManager.updatePowerState(batteryLevel: 50, isCharging: true);
      expect(powerManager.powerMode, PowerMode.performance);
    });

    test('background mode affects power mode', () {
      powerManager.setAppInBackground(true);

      // Normal battery in background -> power saver
      powerManager.updatePowerState(batteryLevel: 80, isCharging: false);
      expect(powerManager.powerMode, PowerMode.powerSaver);

      // Charging in background -> still power saver (not performance)
      powerManager.updatePowerState(batteryLevel: 50, isCharging: true);
      expect(powerManager.powerMode, PowerMode.powerSaver);

      // Critical battery in background -> ultra low power
      powerManager.updatePowerState(batteryLevel: 5, isCharging: false);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);
    });

    test('returns appropriate scan duty cycle per power mode', () {
      powerManager.updatePowerState(batteryLevel: 100, isCharging: true);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.performance);
      final perfCycle = powerManager.getScanDutyCycle();
      expect(perfCycle.onDuration, equals(const Duration(hours: 1)));
      expect(perfCycle.offDuration, equals(Duration.zero));

      powerManager.updatePowerState(batteryLevel: 60, isCharging: false);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.balanced);
      final balancedCycle = powerManager.getScanDutyCycle();
      expect(balancedCycle.onDuration, equals(const Duration(seconds: 8)));
      expect(balancedCycle.offDuration, equals(const Duration(seconds: 2)));

      powerManager.updatePowerState(batteryLevel: 15, isCharging: false);
      expect(powerManager.powerMode, PowerMode.powerSaver);
      final saverCycle = powerManager.getScanDutyCycle();
      expect(saverCycle.onDuration, equals(const Duration(seconds: 2)));
      expect(saverCycle.offDuration, equals(const Duration(seconds: 28)));

      powerManager.updatePowerState(batteryLevel: 5, isCharging: false);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);
      final ultraCycle = powerManager.getScanDutyCycle();
      expect(ultraCycle.onDuration, equals(const Duration(seconds: 1)));
      expect(ultraCycle.offDuration, equals(const Duration(seconds: 29)));
    });

    test('returns appropriate connection limits per power mode', () {
      powerManager.updatePowerState(batteryLevel: 100, isCharging: true);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.performance);
      final perfLimits = powerManager.getConnectionLimits();
      expect(perfLimits.maxConnections, 8);
      expect(perfLimits.rssiThreshold, -95);

      powerManager.updatePowerState(batteryLevel: 60, isCharging: false);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.balanced);
      final balancedLimits = powerManager.getConnectionLimits();
      expect(balancedLimits.maxConnections, 8);
      expect(balancedLimits.rssiThreshold, -85);

      powerManager.updatePowerState(batteryLevel: 15, isCharging: false);
      expect(powerManager.powerMode, PowerMode.powerSaver);
      final saverLimits = powerManager.getConnectionLimits();
      expect(saverLimits.maxConnections, 8);
      expect(saverLimits.rssiThreshold, -75);

      powerManager.updatePowerState(batteryLevel: 5, isCharging: false);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);
      final ultraLimits = powerManager.getConnectionLimits();
      expect(ultraLimits.maxConnections, 4);
      expect(ultraLimits.rssiThreshold, -65);
    });

    test('returns appropriate message frequency per power mode', () {
      powerManager.updatePowerState(batteryLevel: 100, isCharging: true);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.performance);
      final perfFreq = powerManager.getMessageFrequency();
      expect(perfFreq.interval, equals(const Duration(milliseconds: 100)));
      expect(perfFreq.burstLimit, 50);

      powerManager.updatePowerState(batteryLevel: 60, isCharging: false);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.balanced);
      final balancedFreq = powerManager.getMessageFrequency();
      expect(balancedFreq.interval, equals(const Duration(milliseconds: 250)));
      expect(balancedFreq.burstLimit, 20);

      powerManager.updatePowerState(batteryLevel: 15, isCharging: false);
      expect(powerManager.powerMode, PowerMode.powerSaver);
      final saverFreq = powerManager.getMessageFrequency();
      expect(saverFreq.interval, equals(const Duration(milliseconds: 500)));
      expect(saverFreq.burstLimit, 10);

      powerManager.updatePowerState(batteryLevel: 5, isCharging: false);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);
      final ultraFreq = powerManager.getMessageFrequency();
      expect(ultraFreq.interval, equals(const Duration(seconds: 1)));
      expect(ultraFreq.burstLimit, 5);
    });

    test('shouldUseDutyCycle returns correct value', () {
      powerManager.updatePowerState(batteryLevel: 100, isCharging: true);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.performance);
      expect(powerManager.shouldUseDutyCycle(), isFalse);

      powerManager.updatePowerState(batteryLevel: 60, isCharging: false);
      expect(powerManager.powerMode, PowerMode.balanced);
      expect(powerManager.shouldUseDutyCycle(), isTrue);

      powerManager.updatePowerState(batteryLevel: 15, isCharging: false);
      expect(powerManager.powerMode, PowerMode.powerSaver);
      expect(powerManager.shouldUseDutyCycle(), isTrue);

      powerManager.updatePowerState(batteryLevel: 5, isCharging: false);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);
      expect(powerManager.shouldUseDutyCycle(), isTrue);
    });

    test('scan state listeners are notified', () {
      var scanState = false;
      void listener(bool scanning) => scanState = scanning;
      powerManager.addScanStateListener(listener);

      powerManager.startAdaptiveScanning();
      expect(powerManager.isScanning, isTrue);

      powerManager.stopAdaptiveScanning();
      expect(powerManager.isScanning, isFalse);
    });

    test('generates diagnostic information', () {
      final diagnostics = powerManager.getDiagnostics();
      expect(diagnostics, contains('Power Manager Diagnostics'));
      expect(diagnostics, contains('Power Mode'));
      expect(diagnostics, contains('Battery Level'));
      expect(diagnostics, contains('Connection Limits'));
      expect(diagnostics, contains('Message Frequency'));
      expect(diagnostics, contains('Scan Duty Cycle'));
    });

    test('power mode changes trigger notifications', () {
      var notified = false;
      powerManager.addListener(() => notified = true);

      powerManager.updatePowerState(batteryLevel: 80, isCharging: false);
      expect(powerManager.powerMode, PowerMode.balanced);

      powerManager.updatePowerState(batteryLevel: 5, isCharging: false);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);
      expect(notified, isTrue);
    });

    test('app background state affects power mode', () {
      powerManager.updatePowerState(batteryLevel: 60, isCharging: false);
      powerManager.setAppInBackground(false);
      expect(powerManager.powerMode, PowerMode.balanced);

      powerManager.setAppInBackground(true);
      expect(powerManager.powerMode, PowerMode.powerSaver);
    });

    test('critical battery overrides foreground state', () {
      powerManager.setAppInBackground(false);
      powerManager.updatePowerState(batteryLevel: 5, isCharging: true);
      expect(powerManager.powerMode, PowerMode.ultraLowPower);
    });
  });

  group('BatteryThresholds', () {
    test('classifies battery levels correctly', () {
      expect(BatteryThresholds.isCritical(5), isTrue);
      expect(BatteryThresholds.isCritical(10), isTrue);
      expect(BatteryThresholds.isCritical(11), isFalse);

      expect(BatteryThresholds.isLow(15), isTrue);
      expect(BatteryThresholds.isLow(20), isTrue);
      expect(BatteryThresholds.isLow(21), isFalse);
      expect(BatteryThresholds.isLow(10), isFalse);

      expect(BatteryThresholds.isMedium(30), isTrue);
      expect(BatteryThresholds.isMedium(50), isTrue);
      expect(BatteryThresholds.isMedium(51), isFalse);
      expect(BatteryThresholds.isMedium(20), isFalse);

      expect(BatteryThresholds.isNormal(60), isTrue);
      expect(BatteryThresholds.isNormal(100), isTrue);
      expect(BatteryThresholds.isNormal(50), isFalse);
    });
  });

  group('PowerMode enum', () {
    test('has all expected values', () {
      expect(
          PowerMode.values,
          containsAll([
            PowerMode.performance,
            PowerMode.balanced,
            PowerMode.powerSaver,
            PowerMode.ultraLowPower,
          ]));
    });
  });

  group('ScanDutyCycle', () {
    test('has appropriate values for each power mode', () {
      expect(
          ScanDutyCycle.normal.onDuration, equals(const Duration(seconds: 8)));
      expect(
          ScanDutyCycle.normal.offDuration, equals(const Duration(seconds: 2)));

      expect(ScanDutyCycle.powerSaver.onDuration,
          equals(const Duration(seconds: 2)));
      expect(ScanDutyCycle.powerSaver.offDuration,
          equals(const Duration(seconds: 28)));

      expect(ScanDutyCycle.ultraLowPower.onDuration,
          equals(const Duration(seconds: 1)));
      expect(ScanDutyCycle.ultraLowPower.offDuration,
          equals(const Duration(seconds: 29)));

      expect(ScanDutyCycle.continuous.onDuration,
          equals(const Duration(hours: 1)));
      expect(ScanDutyCycle.continuous.offDuration, equals(Duration.zero));
    });
  });

  group('ConnectionLimits', () {
    test('has appropriate values for each power mode', () {
      expect(ConnectionLimits.performance.maxConnections, 8);
      expect(ConnectionLimits.performance.rssiThreshold, -95);

      expect(ConnectionLimits.balanced.maxConnections, 8);
      expect(ConnectionLimits.balanced.rssiThreshold, -85);

      expect(ConnectionLimits.powerSaver.maxConnections, 8);
      expect(ConnectionLimits.powerSaver.rssiThreshold, -75);

      expect(ConnectionLimits.ultraLowPower.maxConnections, 4);
      expect(ConnectionLimits.ultraLowPower.rssiThreshold, -65);
    });
  });

  group('MessageFrequency', () {
    test('has appropriate values for each power mode', () {
      expect(MessageFrequency.performance.interval,
          equals(const Duration(milliseconds: 100)));
      expect(MessageFrequency.performance.burstLimit, 50);

      expect(MessageFrequency.balanced.interval,
          equals(const Duration(milliseconds: 250)));
      expect(MessageFrequency.balanced.burstLimit, 20);

      expect(MessageFrequency.powerSaver.interval,
          equals(const Duration(milliseconds: 500)));
      expect(MessageFrequency.powerSaver.burstLimit, 10);

      expect(MessageFrequency.ultraLowPower.interval,
          equals(const Duration(seconds: 1)));
      expect(MessageFrequency.ultraLowPower.burstLimit, 5);
    });
  });

  group('PowerState', () {
    test('implements copyWith correctly', () {
      final state1 = PowerState(
        batteryLevel: 50,
        isCharging: false,
        isPowerSaveMode: false,
        platform: 'android',
        powerMode: PowerMode.balanced,
        timestamp: DateTime(2024, 1, 1),
      );

      final state2 = state1.copyWith(batteryLevel: 75);

      expect(state1.batteryLevel, 50);
      expect(state2.batteryLevel, 75);
      expect(state2.isCharging, state1.isCharging);
      expect(state2.platform, state1.platform);
    });

    test('implements equality correctly', () {
      final state1 = PowerState(
        batteryLevel: 50,
        isCharging: false,
        isPowerSaveMode: false,
        platform: 'android',
        powerMode: PowerMode.balanced,
        timestamp: DateTime(2024, 1, 1),
      );

      final state2 = PowerState(
        batteryLevel: 50,
        isCharging: false,
        isPowerSaveMode: false,
        platform: 'android',
        powerMode: PowerMode.balanced,
        timestamp: DateTime(2024, 1, 1),
      );

      final state3 = PowerState(
        batteryLevel: 75,
        isCharging: false,
        isPowerSaveMode: false,
        platform: 'android',
        powerMode: PowerMode.balanced,
        timestamp: DateTime(2024, 1, 1),
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('has proper string representation', () {
      final state = PowerState(
        batteryLevel: 50,
        isCharging: false,
        isPowerSaveMode: false,
        platform: 'android',
        powerMode: PowerMode.balanced,
        timestamp: DateTime(2024, 1, 1),
      );

      final string = state.toString();
      expect(string, contains('PowerState'));
      expect(string, contains('batteryLevel: 50%'));
      expect(string, contains('isCharging: false'));
      expect(string, contains('powerMode: PowerMode.balanced'));
    });
  });
}
