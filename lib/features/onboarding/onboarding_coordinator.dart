import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitchat/features/mesh/ble_manager.dart';
import 'package:bitchat/features/onboarding/onboarding_state.dart';
import 'package:bitchat/features/permissions/permission_service.dart';

/// Bluetooth status enum
enum BluetoothStatus {
  enabled,
  disabled,
  notSupported,
  unknown,
}

/// Location status enum
enum LocationStatus {
  enabled,
  disabled,
  unknown,
}

/// Onboarding coordinator - manages the complete onboarding flow.
/// Matches Android's OnboardingCoordinator implementation.
class OnboardingCoordinator extends ChangeNotifier {
  static const String _tag = 'OnboardingCoordinator';

  final PermissionService _permissionService;

  OnboardingState _state = OnboardingState.checking;
  String? _errorMessage;
  BluetoothStatus _bluetoothStatus = BluetoothStatus.unknown;
  LocationStatus _locationStatus = LocationStatus.unknown;

  // Callbacks
  VoidCallback? onOnboardingComplete;
  void Function(String error)? onOnboardingFailed;

  OnboardingCoordinator({
    PermissionService? permissionService,
  }) : _permissionService = permissionService ?? PermissionService();

  /// Current onboarding state
  OnboardingState get state => _state;

  /// Error message if in error state
  String? get errorMessage => _errorMessage;

  /// Current bluetooth status
  BluetoothStatus get bluetoothStatus => _bluetoothStatus;

  /// Current location status
  LocationStatus get locationStatus => _locationStatus;

  /// Start the onboarding process
  Future<void> startOnboarding() async {
    debugPrint('$_tag: Starting onboarding process');

    // Log current permission status
    await _permissionService.logPermissionStatus();

    // Check if all required permissions are already granted
    final allGranted = await _permissionService.areRequiredPermissionsGranted();

    if (allGranted) {
      debugPrint('$_tag: All permissions already granted, checking BLE status');
      await _checkBluetoothStatus();
    } else {
      debugPrint('$_tag: Missing permissions, starting explanation flow');
      _setState(OnboardingState.bluetoothCheck);
      await _checkBluetoothStatus();
    }
  }

  /// Check if Bluetooth is enabled and supported
  Future<void> _checkBluetoothStatus() async {
    _setState(OnboardingState.bluetoothCheck);

    try {
      // Initialize BleManager first
      final initialized = await BleManager.instance.initialize();
      if (!initialized) {
        _bluetoothStatus = BluetoothStatus.notSupported;
        notifyListeners();
        return;
      }

      final state = BleManager.instance.state;
      debugPrint('$_tag: BLE state is $state');

      if (state == BluetoothLowEnergyState.poweredOn) {
        _bluetoothStatus = BluetoothStatus.enabled;
        await _checkLocationStatus();
      } else if (state == BluetoothLowEnergyState.unsupported) {
        _bluetoothStatus = BluetoothStatus.notSupported;
        notifyListeners();
      } else if (state == BluetoothLowEnergyState.unauthorized) {
        // Permissions not granted - need to request BLE permissions first
        debugPrint('$_tag: BLE unauthorized - need to request permissions');
        _bluetoothStatus = BluetoothStatus.disabled;
        // Go directly to permission explanation/request flow
        await _proceedToPermissionExplanation();
      } else {
        // poweredOff or unknown
        _bluetoothStatus = BluetoothStatus.disabled;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('$_tag: Error checking Bluetooth status: $e');
      _bluetoothStatus = BluetoothStatus.unknown;
      notifyListeners();
    }
  }

  /// Request to enable Bluetooth - now also requests permissions if needed
  Future<void> requestEnableBluetooth() async {
    try {
      final state = BleManager.instance.state;

      if (state == BluetoothLowEnergyState.unauthorized) {
        // Need permissions first - go to permission flow
        debugPrint('$_tag: Requesting BLE permissions...');
        await _proceedToPermissionExplanation();
        return;
      }

      if (Platform.isAndroid && state == BluetoothLowEnergyState.poweredOff) {
        // Try to authorize which may prompt system dialog
        debugPrint('$_tag: Trying to authorize BLE...');
        try {
          await BleManager.instance.central.authorize();
        } catch (e) {
          debugPrint('$_tag: authorize() not available or failed: $e');
        }
      }

      // Re-check status after request
      await _checkBluetoothStatus();
    } catch (e) {
      debugPrint('$_tag: Error enabling Bluetooth: $e');
    }
  }

  /// Check if Location is enabled
  Future<void> _checkLocationStatus() async {
    _setState(OnboardingState.locationCheck);

    // On Android, location is required for BLE scanning
    if (Platform.isAndroid) {
      // Check location permission status
      final locationStatus =
          await _permissionService.checkPermission(PermissionType.location);
      if (locationStatus.isGranted) {
        _locationStatus = LocationStatus.enabled;
        await _proceedToPermissionExplanation();
      } else {
        _locationStatus = LocationStatus.disabled;
        notifyListeners();
      }
    } else {
      // iOS doesn't strictly require location for BLE
      _locationStatus = LocationStatus.enabled;
      await _proceedToPermissionExplanation();
    }
  }

  /// Proceed to permission explanation screen
  Future<void> _proceedToPermissionExplanation() async {
    // Check if permissions are needed
    final missing = await _permissionService.getMissingPermissions();

    if (missing.isEmpty) {
      // All permissions granted, skip to initialization
      await _initializeMeshService();
    } else {
      // Show explanation screen
      _setState(OnboardingState.permissionExplanation);
    }
  }

  /// User accepted permission explanation, request permissions
  Future<void> requestPermissions() async {
    debugPrint('$_tag: User accepted explanation, requesting permissions');
    _setState(OnboardingState.permissionRequesting);

    try {
      final missing = await _permissionService.getMissingPermissions();
      if (missing.isEmpty) {
        await _initializeMeshService();
        return;
      }

      final results = await _permissionService.requestPermissions(missing);

      // Check if critical permissions are granted
      final criticalDenied = results.entries
          .where((e) => _isCriticalPermission(e.key) && !e.value.isGranted)
          .toList();

      if (criticalDenied.isEmpty) {
        debugPrint('$_tag: All critical permissions granted');
        await _initializeMeshService();
      } else {
        debugPrint('$_tag: Critical permissions denied: $criticalDenied');
        _handlePermissionDenial(criticalDenied);
      }
    } catch (e) {
      debugPrint('$_tag: Error requesting permissions: $e');
      _setError('Failed to request permissions: $e');
    }
  }

  /// Check if a permission type is critical (required)
  bool _isCriticalPermission(PermissionType type) {
    return type == PermissionType.bluetoothScan ||
        type == PermissionType.bluetoothConnect ||
        type == PermissionType.bluetoothAdvertise ||
        type == PermissionType.location;
  }

  /// Handle permission denial
  void _handlePermissionDenial(
    List<MapEntry<PermissionType, AppPermissionStatus>> denied,
  ) {
    final permissionNames =
        denied.map((e) => _getPermissionDisplayName(e.key)).join(', ');
    _setError(
      'Critical permissions were denied: $permissionNames. '
      'Please grant these permissions in Settings to use bitchat.',
    );
  }

  /// Get human-readable permission name
  String _getPermissionDisplayName(PermissionType type) {
    switch (type) {
      case PermissionType.bluetoothScan:
      case PermissionType.bluetoothConnect:
      case PermissionType.bluetoothAdvertise:
        return 'Bluetooth';
      case PermissionType.location:
      case PermissionType.locationWhenInUse:
        return 'Location';
      case PermissionType.locationAlways:
        return 'Background Location';
      case PermissionType.notification:
        return 'Notifications';
      case PermissionType.batteryOptimization:
        return 'Battery Optimization';
    }
  }

  /// Initialize the mesh service
  Future<void> _initializeMeshService() async {
    debugPrint('$_tag: Initializing mesh service');
    _setState(OnboardingState.initializing);

    try {
      // Give UI time to update
      await Future.delayed(const Duration(milliseconds: 500));

      // Complete onboarding
      _setState(OnboardingState.complete);
      onOnboardingComplete?.call();
    } catch (e) {
      debugPrint('$_tag: Error initializing mesh: $e');
      _setError('Failed to initialize mesh: $e');
    }
  }

  /// Skip location check (if user declines)
  Future<void> skipLocationCheck() async {
    _locationStatus = LocationStatus.disabled;
    await _proceedToPermissionExplanation();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await _permissionService.openAppSettings();
  }

  /// Retry from error state
  Future<void> retry() async {
    _errorMessage = null;
    await startOnboarding();
  }

  /// Set state and notify
  void _setState(OnboardingState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Set error state
  void _setError(String message) {
    _errorMessage = message;
    _state = OnboardingState.error;
    notifyListeners();
    onOnboardingFailed?.call(message);
  }
}

/// Provider for OnboardingCoordinator
final onboardingCoordinatorProvider =
    ChangeNotifierProvider<OnboardingCoordinator>((ref) {
  return OnboardingCoordinator();
});
