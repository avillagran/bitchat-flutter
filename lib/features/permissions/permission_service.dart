import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Permission status for the bitchat app
enum PermissionType {
  bluetoothScan,
  bluetoothConnect,
  bluetoothAdvertise,
  location,
  locationAlways,
  locationWhenInUse,
  notification,
  batteryOptimization,
}

/// App-specific permission status with additional metadata
class AppPermissionStatus {
  final PermissionType type;
  final ph.Permission permission;
  final bool isGranted;
  final bool isPermanentlyDenied;
  final bool isLimited;
  final bool isRestricted;
  final bool isProvisional;

  const AppPermissionStatus({
    required this.type,
    required this.permission,
    required this.isGranted,
    required this.isPermanentlyDenied,
    required this.isLimited,
    required this.isRestricted,
    required this.isProvisional,
  });

  /// Returns true if permission is granted or limited (iOS)
  bool get isAvailable => isGranted || isLimited;

  /// Returns true if permission can be requested again
  bool get canRequest => !isPermanentlyDenied && !isRestricted;

  @override
  String toString() {
    return 'AppPermissionStatus(type: $type, isGranted: $isGranted, '
        'isPermanentlyDenied: $isPermanentlyDenied, canRequest: $canRequest)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppPermissionStatus &&
        other.type == type &&
        other.isGranted == isGranted &&
        other.isPermanentlyDenied == isPermanentlyDenied;
  }

  @override
  int get hashCode =>
      type.hashCode ^ isGranted.hashCode ^ isPermanentlyDenied.hashCode;
}

/// Centralized permission management for bitchat app
/// Handles all Bluetooth, location, and notification permissions
/// required for the app to function properly
class PermissionService {
  static const String _tag = 'PermissionService';

  /// Get required permissions based on platform
  List<PermissionType> get requiredPermissions {
    final required = <PermissionType>[
      PermissionType.location,
      PermissionType.bluetoothScan,
      PermissionType.bluetoothConnect,
      PermissionType.bluetoothAdvertise,
    ];

    // Android 10+ (API 29) requires background location for background BLE scanning
    if (Platform.isAndroid && _needsBackgroundLocationPermission()) {
      required.add(PermissionType.locationAlways);
    }

    return required;
  }

  /// Get optional permissions that improve experience but aren't required
  List<PermissionType> get optionalPermissions {
    return [
      PermissionType.notification,
      PermissionType.batteryOptimization,
    ];
  }

  /// Check if background location permission is needed
  bool _needsBackgroundLocationPermission() {
    if (!Platform.isAndroid) return false;
    return true; // For Android 10+ (API 29)
  }

  /// Convert PermissionType to Permission enum from permission_handler
  ph.Permission _getPermission(PermissionType type) {
    switch (type) {
      case PermissionType.bluetoothScan:
        return ph.Permission.bluetoothScan;
      case PermissionType.bluetoothConnect:
        return ph.Permission.bluetoothConnect;
      case PermissionType.bluetoothAdvertise:
        return ph.Permission.bluetoothAdvertise;
      case PermissionType.location:
        return ph.Permission.location;
      case PermissionType.locationAlways:
        return ph.Permission.locationAlways;
      case PermissionType.locationWhenInUse:
        return ph.Permission.locationWhenInUse;
      case PermissionType.notification:
        return ph.Permission.notification;
      case PermissionType.batteryOptimization:
        // This is handled differently, return a placeholder
        return ph.Permission.unknown;
    }
  }

  /// Check the status of a specific permission
  Future<AppPermissionStatus> checkPermission(PermissionType type) async {
    // Desktop platforms (macOS, Windows, Linux) don't support permission_handler
    // Return granted status to allow the app to function
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return AppPermissionStatus(
        type: type,
        permission: _getPermission(type),
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );
    }

    if (type == PermissionType.batteryOptimization) {
      return _checkBatteryOptimizationPermission();
    }

    final permission = _getPermission(type);

    ph.PermissionStatus status;
    try {
      status = await permission.status;
    } on MissingPluginException {
      // Plugin not implemented for this platform
      debugPrint('$_tag: Permission plugin not available, assuming granted');
      return AppPermissionStatus(
        type: type,
        permission: permission,
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );
    }

    return AppPermissionStatus(
      type: type,
      permission: permission,
      isGranted: status.isGranted,
      isPermanentlyDenied: status.isPermanentlyDenied,
      isLimited: status.isLimited,
      isRestricted: status.isRestricted,
      isProvisional: status.isProvisional,
    );
  }

  /// Check battery optimization permission (Android only)
  Future<AppPermissionStatus> _checkBatteryOptimizationPermission() async {
    // Only Android supports battery optimization permissions
    if (!Platform.isAndroid) {
      return const AppPermissionStatus(
        type: PermissionType.batteryOptimization,
        permission: ph.Permission.unknown,
        isGranted: true, // Not applicable on iOS/macOS/Windows/Linux
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );
    }

    try {
      final channel = MethodChannel('com.bitchat.permissions/native');
      final bool isIgnored =
          await channel.invokeMethod('isBatteryOptimizationDisabled');

      return AppPermissionStatus(
        type: PermissionType.batteryOptimization,
        permission: ph.Permission.unknown,
        isGranted: isIgnored,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );
    } catch (e) {
      // If native call fails, default to false (not whitelisted)
      return const AppPermissionStatus(
        type: PermissionType.batteryOptimization,
        permission: ph.Permission.unknown,
        isGranted: false,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );
    }
  }

  /// Request a specific permission
  Future<AppPermissionStatus> requestPermission(PermissionType type) async {
    // Desktop platforms don't support permission requests
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return AppPermissionStatus(
        type: type,
        permission: _getPermission(type),
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );
    }

    if (type == PermissionType.batteryOptimization) {
      throw ArgumentError(
        'Battery optimization cannot be requested via this method. '
        'Use openBatteryOptimizationSettings() instead.',
      );
    }

    final permission = _getPermission(type);

    ph.PermissionStatus status;
    try {
      status = await permission.request();
    } on MissingPluginException {
      debugPrint('$_tag: Permission plugin not available, assuming granted');
      return AppPermissionStatus(
        type: type,
        permission: permission,
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );
    }

    return AppPermissionStatus(
      type: type,
      permission: permission,
      isGranted: status.isGranted,
      isPermanentlyDenied: status.isPermanentlyDenied,
      isLimited: status.isLimited,
      isRestricted: status.isRestricted,
      isProvisional: status.isProvisional,
    );
  }

  /// Request multiple permissions at once
  Future<Map<PermissionType, AppPermissionStatus>> requestPermissions(
    List<PermissionType> types,
  ) async {
    // Desktop platforms don't support permission requests
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      final result = <PermissionType, AppPermissionStatus>{};
      for (final type in types) {
        result[type] = AppPermissionStatus(
          type: type,
          permission: _getPermission(type),
          isGranted: true,
          isPermanentlyDenied: false,
          isLimited: false,
          isRestricted: false,
          isProvisional: false,
        );
      }
      return result;
    }

    // Filter out battery optimization (not requestable)
    final requestableTypes =
        types.where((t) => t != PermissionType.batteryOptimization).toList();

    final permissions = requestableTypes.map(_getPermission).toList();

    Map<ph.Permission, ph.PermissionStatus> statuses;
    try {
      statuses = await permissions.request();
    } on MissingPluginException {
      debugPrint('$_tag: Permission plugin not available, assuming granted');
      final result = <PermissionType, AppPermissionStatus>{};
      for (final type in types) {
        result[type] = AppPermissionStatus(
          type: type,
          permission: _getPermission(type),
          isGranted: true,
          isPermanentlyDenied: false,
          isLimited: false,
          isRestricted: false,
          isProvisional: false,
        );
      }
      return result;
    }

    final result = <PermissionType, AppPermissionStatus>{};
    for (var i = 0; i < requestableTypes.length; i++) {
      final type = requestableTypes[i];
      final permission = permissions[i];
      final packageStatus = statuses[permission] ?? ph.PermissionStatus.denied;

      result[type] = AppPermissionStatus(
        type: type,
        permission: permission,
        isGranted: packageStatus.isGranted,
        isPermanentlyDenied: packageStatus.isPermanentlyDenied,
        isLimited: packageStatus.isLimited,
        isRestricted: packageStatus.isRestricted,
        isProvisional: packageStatus.isProvisional,
      );
    }

    return result;
  }

  /// Check if all required permissions are granted
  Future<bool> areRequiredPermissionsGranted() async {
    for (final type in requiredPermissions) {
      final status = await checkPermission(type);
      if (!status.isAvailable) {
        return false;
      }
    }
    return true;
  }

  /// Get list of missing required permissions
  Future<List<PermissionType>> getMissingPermissions() async {
    final missing = <PermissionType>[];

    for (final type in requiredPermissions) {
      final status = await checkPermission(type);
      if (!status.isAvailable) {
        missing.add(type);
      }
    }

    return missing;
  }

  /// Get status of all permissions (required and optional)
  Future<Map<PermissionType, AppPermissionStatus>>
      getAllPermissionsStatus() async {
    final allTypes = [...requiredPermissions, ...optionalPermissions];
    final result = <PermissionType, AppPermissionStatus>{};

    for (final type in allTypes) {
      result[type] = await checkPermission(type);
    }

    return result;
  }

  /// Open app settings to allow user to grant permissions
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  /// Open battery optimization settings (Android only)
  Future<bool> openBatteryOptimizationSettings() async {
    if (!Platform.isAndroid) {
      debugPrint('$_tag: Battery optimization settings not available on iOS');
      return false;
    }

    try {
      final channel = MethodChannel('com.bitchat.permissions/native');
      final result =
          await channel.invokeMethod('requestDisableBatteryOptimization');
      return result == true;
    } catch (e) {
      debugPrint('$_tag: Failed to open battery optimization settings: $e');
      return false;
    }
  }

  /// Request background location permission
  /// This should be called after foreground location is granted on Android
  Future<AppPermissionStatus> requestBackgroundLocation() async {
    if (!Platform.isAndroid) {
      return checkPermission(PermissionType.locationAlways);
    }

    return requestPermission(PermissionType.locationAlways);
  }

  /// Get platform-specific permission information
  Map<String, dynamic> getPlatformInfo() {
    return {
      'platform': Platform.operatingSystem,
      'androidSdk': Platform.isAndroid ? 'Android' : 'N/A',
      'needsBackgroundLocation': _needsBackgroundLocationPermission(),
      'requiredPermissions': requiredPermissions.map((t) => t.name).toList(),
      'optionalPermissions': optionalPermissions.map((t) => t.name).toList(),
    };
  }

  /// Get diagnostic information about permissions
  Future<String> getDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Permission Diagnostics ===');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln();

    final statuses = await getAllPermissionsStatus();

    buffer.writeln('Required Permissions:');
    for (final type in requiredPermissions) {
      final status = statuses[type]!;
      buffer.writeln(
        '  ${type.name}: ${status.isAvailable ? "✅ GRANTED" : "❌ MISSING"} '
        '(canRequest: ${status.canRequest})',
      );
    }

    buffer.writeln();
    buffer.writeln('Optional Permissions:');
    for (final type in optionalPermissions) {
      final status = statuses[type]!;
      buffer.writeln(
        '  ${type.name}: ${status.isAvailable ? "✅ GRANTED" : "❌ MISSING"} '
        '(canRequest: ${status.canRequest})',
      );
    }

    final missing = await getMissingPermissions();
    if (missing.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Missing Permissions:');
      for (final type in missing) {
        buffer.writeln('  - ${type.name}');
      }
    }

    return buffer.toString();
  }

  /// Log current permission status for debugging
  Future<void> logPermissionStatus() async {
    debugPrint(await getDiagnostics());
  }
}
