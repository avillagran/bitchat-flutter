import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:bitchat/features/permissions/permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Suppress debug prints for cleaner test output
  debugPrint = (String? message, {int? wrapWidth}) {};

  group('PermissionService', () {
    late PermissionService permissionService;

    setUp(() {
      permissionService = PermissionService();
    });

    test('should have required permissions', () {
      final required = permissionService.requiredPermissions;
      expect(required, contains(PermissionType.location));
      expect(required, contains(PermissionType.bluetoothScan));
      expect(required, contains(PermissionType.bluetoothConnect));
      expect(required, contains(PermissionType.bluetoothAdvertise));
    });

    test('should have optional permissions', () {
      final optional = permissionService.optionalPermissions;
      expect(optional, contains(PermissionType.notification));
      expect(optional, contains(PermissionType.batteryOptimization));
    });

    test('should get platform info', () {
      final info = permissionService.getPlatformInfo();
      expect(info.containsKey('platform'), isTrue);
      expect(info.containsKey('requiredPermissions'), isTrue);
      expect(info.containsKey('optionalPermissions'), isTrue);
    });

    test('should throw error for battery optimization request', () {
      expect(
        () => permissionService.requestPermission(PermissionType.batteryOptimization),
        throwsArgumentError,
      );
    });

    test('should have permission status properties', () {
      final status = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      expect(status.isAvailable, isTrue);
      expect(status.canRequest, isTrue);
      expect(status.toString(), contains('AppPermissionStatus'));
    });

    test('should handle permission equality', () {
      final status1 = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      final status2 = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      final status3 = AppPermissionStatus(
        type: PermissionType.bluetoothScan,
        permission: ph.Permission.bluetoothScan,
        isGranted: false,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      expect(status1, equals(status2));
      expect(status1, isNot(equals(status3)));
    });

    test('should calculate permission availability correctly', () {
      final granted = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      final limited = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: false,
        isPermanentlyDenied: false,
        isLimited: true,
        isRestricted: false,
        isProvisional: false,
      );

      final denied = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: false,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      expect(granted.isAvailable, isTrue);
      expect(limited.isAvailable, isTrue);
      expect(denied.isAvailable, isFalse);
    });

    test('should calculate canRequest correctly', () {
      final granted = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: true,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      final permanentlyDenied = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: false,
        isPermanentlyDenied: true,
        isLimited: false,
        isRestricted: false,
        isProvisional: false,
      );

      final restricted = AppPermissionStatus(
        type: PermissionType.location,
        permission: ph.Permission.location,
        isGranted: false,
        isPermanentlyDenied: false,
        isLimited: false,
        isRestricted: true,
        isProvisional: false,
      );

      expect(granted.canRequest, isTrue);
      expect(permanentlyDenied.canRequest, isFalse);
      expect(restricted.canRequest, isFalse);
    });
  });

  group('PermissionType enum', () {
    test('should have all expected values', () {
      expect(PermissionType.values, containsAll([
        PermissionType.bluetoothScan,
        PermissionType.bluetoothConnect,
        PermissionType.bluetoothAdvertise,
        PermissionType.location,
        PermissionType.locationAlways,
        PermissionType.locationWhenInUse,
        PermissionType.notification,
        PermissionType.batteryOptimization,
      ]));
    });
  });
}
