import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitchat/features/geohash/geohash_utils.dart';
import 'package:bitchat/features/location/location_service.dart';
import 'package:bitchat/features/permissions/permission_service.dart';

/// Permission state for location services.
/// Matches Android LocationChannelManager.PermissionState.
enum LocationPermissionState {
  notDetermined,
  authorized,
  denied,
  restricted,
}

/// State for the location channel manager.
class LocationChannelState {
  final LocationPermissionState permissionState;
  final List<GeohashChannel> availableChannels;
  final ChannelId? selectedChannel;
  final Map<GeohashChannelLevel, String> locationNames;
  final bool locationServicesEnabled;
  final bool isTeleported;
  final Set<String> bookmarks;
  final Map<String, String> bookmarkNames;

  const LocationChannelState({
    this.permissionState = LocationPermissionState.notDetermined,
    this.availableChannels = const [],
    this.selectedChannel,
    this.locationNames = const {},
    this.locationServicesEnabled = false,
    this.isTeleported = false,
    this.bookmarks = const {},
    this.bookmarkNames = const {},
  });

  LocationChannelState copyWith({
    LocationPermissionState? permissionState,
    List<GeohashChannel>? availableChannels,
    ChannelId? selectedChannel,
    bool clearSelectedChannel = false,
    Map<GeohashChannelLevel, String>? locationNames,
    bool? locationServicesEnabled,
    bool? isTeleported,
    Set<String>? bookmarks,
    Map<String, String>? bookmarkNames,
  }) {
    return LocationChannelState(
      permissionState: permissionState ?? this.permissionState,
      availableChannels: availableChannels ?? this.availableChannels,
      selectedChannel: clearSelectedChannel
          ? null
          : (selectedChannel ?? this.selectedChannel),
      locationNames: locationNames ?? this.locationNames,
      locationServicesEnabled:
          locationServicesEnabled ?? this.locationServicesEnabled,
      isTeleported: isTeleported ?? this.isTeleported,
      bookmarks: bookmarks ?? this.bookmarks,
      bookmarkNames: bookmarkNames ?? this.bookmarkNames,
    );
  }
}

/// Manages location-based channels using geohash.
/// Port of Android LocationChannelManager for Flutter parity.
class LocationChannelManager extends StateNotifier<LocationChannelState> {
  static const String _tag = '[LocationChannelManager]';
  static const String _bookmarksKey = 'geohash_bookmarks';
  static const String _selectedChannelKey = 'selected_channel';

  final LocationService _locationService;
  Timer? _refreshTimer;
  bool _isLiveRefreshActive = false;

  LocationChannelManager({
    LocationService? locationService,
  })  : _locationService = locationService ?? LocationService(),
        super(const LocationChannelState()) {
    _initialize();
  }

  /// Initialize the manager.
  Future<void> _initialize() async {
    await _loadBookmarks();
    await _checkPermissions();
  }

  /// Load bookmarks from storage.
  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksList = prefs.getStringList(_bookmarksKey) ?? [];
      state = state.copyWith(bookmarks: bookmarksList.toSet());
      debugPrint('$_tag Loaded ${bookmarksList.length} bookmarks');
    } catch (e) {
      debugPrint('$_tag Error loading bookmarks: $e');
    }
  }

  /// Save bookmarks to storage.
  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_bookmarksKey, state.bookmarks.toList());
    } catch (e) {
      debugPrint('$_tag Error saving bookmarks: $e');
    }
  }

  /// Check current permission state.
  Future<void> _checkPermissions() async {
    final status = await _locationService.initialize();

    LocationPermissionState permState;
    switch (status) {
      case LocationServiceStatus.enabled:
        permState = LocationPermissionState.authorized;
        break;
      case LocationServiceStatus.permanentlyDenied:
        permState = LocationPermissionState.restricted;
        break;
      case LocationServiceStatus.disabled:
        permState = LocationPermissionState.denied;
        break;
      case LocationServiceStatus.notAvailable:
        permState = LocationPermissionState.notDetermined;
        break;
    }

    state = state.copyWith(
      permissionState: permState,
      locationServicesEnabled: status == LocationServiceStatus.enabled,
    );
  }

  /// Enable location channels by requesting permissions.
  Future<void> enableLocationChannels() async {
    final status = await _locationService.requestPermissions();

    if (status.isAvailable) {
      state = state.copyWith(
        permissionState: LocationPermissionState.authorized,
        locationServicesEnabled: true,
      );
      await refreshChannels();
    } else if (status.isPermanentlyDenied) {
      state = state.copyWith(
        permissionState: LocationPermissionState.restricted,
      );
    } else {
      state = state.copyWith(
        permissionState: LocationPermissionState.denied,
      );
    }
  }

  /// Enable location services.
  Future<void> enableLocationServices() async {
    state = state.copyWith(locationServicesEnabled: true);
    await _checkPermissions();
    if (state.permissionState == LocationPermissionState.authorized) {
      await refreshChannels();
    }
  }

  /// Disable location services.
  void disableLocationServices() {
    _locationService.stopLocationUpdates();
    state = state.copyWith(
      locationServicesEnabled: false,
      availableChannels: [],
    );
  }

  /// Refresh available channels based on current location.
  Future<void> refreshChannels() async {
    if (state.permissionState != LocationPermissionState.authorized) {
      debugPrint('$_tag Cannot refresh: not authorized');
      return;
    }

    final location = await _locationService.getCurrentPosition();
    if (location == null) {
      debugPrint('$_tag Cannot refresh: no location');
      return;
    }

    // Generate channels at different precision levels
    // Filter out building level (precision 8) as per iOS pattern
    final levels = [
      GeohashChannelLevel.region,
      GeohashChannelLevel.province,
      GeohashChannelLevel.city,
      GeohashChannelLevel.neighborhood,
      GeohashChannelLevel.block,
      // building excluded
    ];

    final channels = <GeohashChannel>[];
    final names = <GeohashChannelLevel, String>{};

    for (final level in levels) {
      final channel = GeohashChannel.fromCoordinates(
        location.latitude,
        location.longitude,
        level,
      );
      channels.add(channel);
      names[level] = level.displayName;
    }

    state = state.copyWith(
      availableChannels: channels,
      locationNames: names,
    );

    debugPrint('$_tag Refreshed ${channels.length} channels');
  }

  /// Begin live refresh of channels.
  void beginLiveRefresh() {
    if (_isLiveRefreshActive) return;
    _isLiveRefreshActive = true;

    // Refresh every 30 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => refreshChannels(),
    );

    debugPrint('$_tag Started live refresh');
  }

  /// End live refresh of channels.
  void endLiveRefresh() {
    _isLiveRefreshActive = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    debugPrint('$_tag Stopped live refresh');
  }

  /// Select a channel.
  void select(ChannelId channel) {
    state = state.copyWith(selectedChannel: channel);
    debugPrint('$_tag Selected channel: $channel');
  }

  /// Clear channel selection.
  void clearSelection() {
    state = state.copyWith(clearSelectedChannel: true);
  }

  /// Set teleported state.
  void setTeleported(bool value) {
    state = state.copyWith(isTeleported: value);
  }

  /// Toggle bookmark for a geohash.
  void toggleBookmark(String geohash) {
    final newBookmarks = Set<String>.from(state.bookmarks);
    if (newBookmarks.contains(geohash)) {
      newBookmarks.remove(geohash);
    } else {
      newBookmarks.add(geohash);
    }
    state = state.copyWith(bookmarks: newBookmarks);
    _saveBookmarks();
  }

  /// Check if a geohash is bookmarked.
  bool isBookmarked(String geohash) {
    return state.bookmarks.contains(geohash);
  }

  /// Open app settings.
  Future<void> openAppSettings() async {
    await _locationService.openAppSettings();
  }

  /// Dispose resources.
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}

/// Provider for LocationChannelManager.
final locationChannelManagerProvider =
    StateNotifierProvider<LocationChannelManager, LocationChannelState>((ref) {
  return LocationChannelManager();
});
