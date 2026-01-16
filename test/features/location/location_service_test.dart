import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/location/location_service.dart';
import 'package:bitchat/features/permissions/permission_service.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

void main() {
  group('LocationService', () {
    late LocationService locationService;
    late MockPermissionService mockPermissionService;

    setUp(() {
      mockPermissionService = MockPermissionService();
      locationService =
          LocationService(permissionService: mockPermissionService);
    });

    tearDown(() {
      locationService.dispose();
    });

    test('should initialize with null current location', () {
      expect(locationService.currentLocation, isNull);
    });

    test('should start with disabled status', () {
      expect(locationService.status, LocationServiceStatus.disabled);
      expect(locationService.isEnabled, isFalse);
    });

    test('should add and remove location listeners', () {
      var updateCount = 0;
      void listener(LocationUpdate update) {
        updateCount++;
      }

      locationService.addLocationListener(listener);
      expect(() => locationService.removeLocationListener(listener),
          returnsNormally);
    });

    test('should calculate distance between coordinates', () {
      // New York to Los Angeles (approximately)
      final distance = LocationService.distanceBetween(
        40.7128, // New York latitude
        -74.0060, // New York longitude
        34.0522, // Los Angeles latitude
        -118.2437, // Los Angeles longitude
      );

      // Should be approximately 3,944 km
      expect(distance, greaterThan(3900000));
      expect(distance, lessThan(4000000));
    });
  });

  group('LocationUpdate', () {
    test('should create from Position object', () {
      // Note: In real tests, you'd mock the Position from geolocator
      // For now, we test the structure
      final update = LocationUpdate(
        latitude: 40.7128,
        longitude: -74.0060,
        altitude: 10.0,
        accuracy: 5.0,
        speed: 1.5,
        timestamp: DateTime.now(),
      );

      expect(update.latitude, equals(40.7128));
      expect(update.longitude, equals(-74.0060));
      expect(update.altitude, equals(10.0));
      expect(update.accuracy, equals(5.0));
      expect(update.speed, equals(1.5));
    });

    test('should calculate distance to another location', () {
      final update1 = LocationUpdate(
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime.now(),
      );

      final update2 = LocationUpdate(
        latitude: 34.0522,
        longitude: -118.2437,
        timestamp: DateTime.now(),
      );

      final distance = update1.distanceTo(update2);

      expect(distance, greaterThan(3900000));
      expect(distance, lessThan(4000000));
    });

    test('should implement equality', () {
      final update1 = LocationUpdate(
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final update2 = LocationUpdate(
        latitude: 40.7128,
        longitude: -74.0060,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final update3 = LocationUpdate(
        latitude: 34.0522,
        longitude: -118.2437,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      expect(update1, equals(update2));
      expect(update1, isNot(equals(update3)));
    });

    test('should have proper string representation', () {
      final update = LocationUpdate(
        latitude: 40.7128,
        longitude: -74.0060,
        accuracy: 5.0,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
      );

      final string = update.toString();

      expect(string, contains('LocationUpdate'));
      expect(string, contains('40.7128'));
      expect(string, contains('-74.006'));
      expect(string, contains('5.0'));
    });
  });

  group('LocationServiceStatus', () {
    test('should have all expected values', () {
      expect(
          LocationServiceStatus.values,
          containsAll([
            LocationServiceStatus.enabled,
            LocationServiceStatus.disabled,
            LocationServiceStatus.permanentlyDenied,
            LocationServiceStatus.notAvailable,
          ]));
    });
  });
}

/// Mock PermissionService for testing
class MockPermissionService extends PermissionService {
  @override
  Future<AppPermissionStatus> checkPermission(PermissionType type) async {
    // Return granted status by default for testing
    return AppPermissionStatus(
      type: type,
      permission: PermissionType.location == type
          ? ph.Permission.location
          : ph.Permission.bluetoothScan,
      isGranted: true,
      isPermanentlyDenied: false,
      isLimited: false,
      isRestricted: false,
      isProvisional: false,
    );
  }

  @override
  Future<AppPermissionStatus> requestPermission(PermissionType type) async {
    return AppPermissionStatus(
      type: type,
      permission: PermissionType.location == type
          ? ph.Permission.location
          : ph.Permission.bluetoothScan,
      isGranted: true,
      isPermanentlyDenied: false,
      isLimited: false,
      isRestricted: false,
      isProvisional: false,
    );
  }
}
