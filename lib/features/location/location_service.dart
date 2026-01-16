import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bitchat/features/permissions/permission_service.dart';

/// Location update data for mesh positioning
class LocationUpdate {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final DateTime timestamp;

  const LocationUpdate({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    required this.timestamp,
  });

  /// Create from Position object
  factory LocationUpdate.fromPosition(Position position) {
    return LocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      speed: position.speed,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        position.timestamp.millisecondsSinceEpoch,
      ),
    );
  }

  /// Calculate distance to another location in meters
  double distanceTo(LocationUpdate other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  @override
  String toString() {
    return 'LocationUpdate(lat: $latitude, lng: $longitude, '
        'accuracy: ${accuracy?.toStringAsFixed(1)}m, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationUpdate &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      latitude.hashCode ^ longitude.hashCode ^ timestamp.hashCode;
}

/// Location service status
enum LocationServiceStatus {
  enabled,
  disabled,
  permanentlyDenied,
  notAvailable,
}

/// Minimal location service implementation for mesh positioning
/// Provides location updates and permission handling
class LocationService {
  static const String _tag = 'LocationService';
  final PermissionService _permissionService;

  StreamSubscription<Position>? _positionStreamSubscription;
  LocationUpdate? _currentLocation;
  LocationServiceStatus _status = LocationServiceStatus.disabled;
  final List<void Function(LocationUpdate)> _listeners = [];

  /// Current location update
  LocationUpdate? get currentLocation => _currentLocation;

  /// Current service status
  LocationServiceStatus get status => _status;

  /// Whether location service is enabled
  bool get isEnabled => _status == LocationServiceStatus.enabled;

  LocationService({
    PermissionService? permissionService,
  }) : _permissionService = permissionService ?? PermissionService();

  /// Initialize location service and check permissions
  Future<LocationServiceStatus> initialize() async {
    try {
      // Check if location service is available on this device
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        _status = LocationServiceStatus.disabled;
        debugPrint('$_tag: Location service is disabled');
        return _status;
      }

      // Check location permissions
      final locationPermission = await _permissionService.checkPermission(
        PermissionType.location,
      );

      if (!locationPermission.isAvailable) {
        if (locationPermission.isPermanentlyDenied) {
          _status = LocationServiceStatus.permanentlyDenied;
          debugPrint('$_tag: Location permission permanently denied');
        } else {
          _status = LocationServiceStatus.disabled;
          debugPrint('$_tag: Location permission not granted');
        }
        return _status;
      }

      // For Android, check background location if needed
      if (Platform.isAndroid) {
        final bgPermission = await _permissionService.checkPermission(
          PermissionType.locationAlways,
        );
        if (!bgPermission.isAvailable) {
          debugPrint(
            '$_tag: Background location not granted (required for background scanning)',
          );
          // Not critical for basic operation
        }
      }

      _status = LocationServiceStatus.enabled;
      debugPrint('$_tag: Location service initialized successfully');
      return _status;
    } catch (e, stackTrace) {
      debugPrint('$_tag: Error initializing location service: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
      _status = LocationServiceStatus.notAvailable;
      return _status;
    }
  }

  /// Request location permissions
  Future<AppPermissionStatus> requestPermissions() async {
    final status = await _permissionService.requestPermission(
      PermissionType.location,
    );

    // Update internal status
    if (status.isAvailable) {
      _status = LocationServiceStatus.enabled;
    } else if (status.isPermanentlyDenied) {
      _status = LocationServiceStatus.permanentlyDenied;
    } else {
      _status = LocationServiceStatus.disabled;
    }

    return status;
  }

  /// Open location settings to enable location service
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  /// Open app settings to grant location permissions
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  /// Get current position (one-time)
  Future<LocationUpdate?> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    bool forceAndroidLocationManager = false,
  }) async {
    if (_status != LocationServiceStatus.enabled) {
      debugPrint('$_tag: Location service not enabled');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        forceAndroidLocationManager: forceAndroidLocationManager,
      );

      _currentLocation = LocationUpdate.fromPosition(position);
      debugPrint('$_tag: Got current position: $_currentLocation');
      return _currentLocation;
    } catch (e, stackTrace) {
      debugPrint('$_tag: Error getting current position: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Start listening for location updates
  /// [accuracy] controls the precision of location updates
  /// [distanceFilter] minimum distance between updates in meters
  Future<bool> startLocationUpdates({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) async {
    if (_status != LocationServiceStatus.enabled) {
      debugPrint('$_tag: Location service not enabled');
      return false;
    }

    if (_positionStreamSubscription != null) {
      debugPrint('$_tag: Location updates already active');
      return true;
    }

    try {
      final locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      );

      _positionStreamSubscription =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position position) {
        final update = LocationUpdate.fromPosition(position);
        _currentLocation = update;
        _notifyListeners(update);
        debugPrint('$_tag: Location update: $update');
      }, onError: (error) {
        debugPrint('$_tag: Error in location stream: $error');
      });

      debugPrint('$_tag: Started location updates');
      return true;
    } catch (e, stackTrace) {
      debugPrint('$_tag: Error starting location updates: $e');
      debugPrint('$_tag: Stack trace: $stackTrace');
      return false;
    }
  }

  /// Stop listening for location updates
  void stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    debugPrint('$_tag: Stopped location updates');
  }

  /// Add a listener for location updates
  void addLocationListener(void Function(LocationUpdate) listener) {
    _listeners.add(listener);
  }

  /// Remove a location update listener
  void removeLocationListener(void Function(LocationUpdate) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of a location update
  void _notifyListeners(LocationUpdate update) {
    for (final listener in List.of(_listeners)) {
      try {
        listener(update);
      } catch (e) {
        debugPrint('$_tag: Error notifying listener: $e');
      }
    }
  }

  /// Calculate distance between two coordinates
  static double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Get last known position
  Future<LocationUpdate?> getLastKnownPosition() async {
    if (_currentLocation != null) {
      return _currentLocation;
    }

    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        _currentLocation = LocationUpdate.fromPosition(position);
        return _currentLocation;
      }
    } catch (e) {
      debugPrint('$_tag: Error getting last known position: $e');
    }

    return null;
  }

  /// Get diagnostic information
  Future<String> getDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Location Service Diagnostics ===');
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('Status: $_status');
    buffer.writeln('Service enabled: ${await Geolocator.isLocationServiceEnabled()}');
    buffer.writeln('Current location: ${_currentLocation ?? "None"}');
    buffer.writeln('Active listeners: ${_listeners.length}');
    buffer.writeln('Updates active: ${_positionStreamSubscription != null}');

    // Check permissions
    final permission = await _permissionService.checkPermission(
      PermissionType.location,
    );
    buffer.writeln('Location permission: ${permission.isAvailable ? "Granted" : "Not granted"}');

    if (Platform.isAndroid) {
      final bgPermission = await _permissionService.checkPermission(
        PermissionType.locationAlways,
      );
      buffer.writeln('Background location: ${bgPermission.isAvailable ? "Granted" : "Not granted"}');
    }

    return buffer.toString();
  }

  /// Log diagnostic information
  Future<void> logDiagnostics() async {
    debugPrint(await getDiagnostics());
  }

  /// Dispose resources
  void dispose() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _listeners.clear();
    debugPrint('$_tag: Location service disposed');
  }
}
