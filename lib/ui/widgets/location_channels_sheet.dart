import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:bitchat/features/chat/chat_provider.dart';
import 'package:bitchat/features/geohash/geohash_utils.dart';
import 'package:bitchat/features/geohash/location_channel_manager.dart';
import 'package:bitchat/ui/theme/bitchat_colors.dart';

/// Bottom sheet for selecting location channels (#mesh or #geohash).
/// Full-featured implementation with:
/// - Multi-level geohash selection (Region, Province, City, Neighborhood, Block)
/// - Manual geohash/coordinates input
/// - OpenStreetMap picker for teleporting
/// - Location permission handling
class LocationChannelsSheet extends ConsumerStatefulWidget {
  /// Currently selected channel (null = mesh)
  final String? selectedChannel;

  /// Callback when a channel is selected
  final ValueChanged<String?> onChannelSelected;

  const LocationChannelsSheet({
    super.key,
    this.selectedChannel,
    required this.onChannelSelected,
  });

  @override
  ConsumerState<LocationChannelsSheet> createState() =>
      _LocationChannelsSheetState();
}

class _LocationChannelsSheetState extends ConsumerState<LocationChannelsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _manualInputController = TextEditingController();
  final MapController _mapController = MapController();

  // Teleport state
  LatLng? _teleportLocation;
  String? _teleportGeohash;
  bool _isTeleported = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Initialize location manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationManager = ref.read(locationChannelManagerProvider.notifier);
      locationManager.enableLocationChannels();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _handleMeshSelect() {
    // Clear teleport and select mesh
    setState(() {
      _isTeleported = false;
      _teleportLocation = null;
      _teleportGeohash = null;
    });
    ref.read(chatProvider.notifier).updateCurrentGeohash(null);
    widget.onChannelSelected(null);
    Navigator.of(context).pop();
  }

  void _handleGeohashSelect(GeohashChannel channel) {
    final geohash = channel.geohash;
    ref.read(chatProvider.notifier).updateCurrentGeohash(geohash);
    widget.onChannelSelected(geohash);
    Navigator.of(context).pop();
  }

  void _handleManualInput() {
    final input = _manualInputController.text.trim();
    if (input.isEmpty) return;

    String? geohash;

    // Try to parse as coordinates (lat,lng or lat lng)
    final coordMatch =
        RegExp(r'^(-?\d+\.?\d*)[,\s]+(-?\d+\.?\d*)$').firstMatch(input);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lng = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        geohash = GeohashUtils.encode(lat, lng, precision: 6);
      }
    }

    // Try to parse as geohash
    if (geohash == null && GeohashUtils.isValid(input)) {
      geohash = input.toLowerCase();
    }

    if (geohash != null) {
      setState(() {
        _isTeleported = true;
        _teleportGeohash = geohash;
        try {
          final center = GeohashUtils.decodeCenter(geohash!);
          _teleportLocation = LatLng(center[0], center[1]);
        } catch (_) {}
      });
      ref.read(chatProvider.notifier).updateCurrentGeohash(geohash);
      widget.onChannelSelected(geohash);
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid geohash or coordinates'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleMapTap(LatLng point) {
    final geohash = GeohashUtils.encode(point.latitude, point.longitude, precision: 6);
    setState(() {
      _teleportLocation = point;
      _teleportGeohash = geohash;
    });
  }

  void _handleTeleportConfirm() {
    if (_teleportGeohash != null) {
      setState(() {
        _isTeleported = true;
      });
      ref.read(chatProvider.notifier).updateCurrentGeohash(_teleportGeohash);
      widget.onChannelSelected(_teleportGeohash);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locationState = ref.watch(locationChannelManagerProvider);
    final chatState = ref.watch(chatProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with tabs
          _buildHeader(colorScheme),

          // Tab bar
          Container(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
              indicatorColor: colorScheme.primary,
              labelStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'CHANNELS'),
                Tab(text: 'MANUAL'),
                Tab(text: 'MAP'),
              ],
            ),
          ),

          const Divider(height: 1),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChannelsTab(colorScheme, locationState, chatState),
                _buildManualTab(colorScheme),
                _buildMapTab(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.location_on,
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Location Channels',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: colorScheme.onSurface,
            ),
          ),
          if (_isTeleported) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TELEPORTED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: Colors.orange,
                ),
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: colorScheme.onSurface),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildChannelsTab(
    ColorScheme colorScheme,
    LocationChannelState locationState,
    ChatState chatState,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Location status
        _buildLocationStatus(colorScheme, locationState),

        const SizedBox(height: 16),

        // Mesh channel (always available)
        _buildChannelOption(
          colorScheme,
          icon: Icons.bluetooth,
          label: '#mesh',
          subtitle: 'Bluetooth broadcast to all nearby devices',
          color: BitchatColors.meshBlue,
          isSelected: widget.selectedChannel == null && !_isTeleported,
          onTap: _handleMeshSelect,
        ),

        const SizedBox(height: 12),

        // Location channels header
        if (locationState.permissionState == LocationPermissionState.authorized &&
            locationState.availableChannels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'LOCATION CHANNELS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: colorScheme.onSurface.withOpacity(0.5),
                letterSpacing: 1,
              ),
            ),
          ),

          // Available geohash channels at different levels
          ...locationState.availableChannels.map((channel) {
            final isSelected = widget.selectedChannel == channel.geohash;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildChannelOption(
                colorScheme,
                icon: _getIconForLevel(channel.level),
                label: '#${channel.geohash}',
                subtitle: '${channel.level.displayName} • ${channel.coverageString}',
                color: BitchatColors.locationGreen,
                isSelected: isSelected,
                onTap: () => _handleGeohashSelect(channel),
              ),
            );
          }),
        ] else if (locationState.permissionState != LocationPermissionState.authorized) ...[
          // Permission not granted
          _buildPermissionPrompt(colorScheme, locationState),
        ] else ...[
          // Loading or no channels
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Getting your location...',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Info text
        _buildInfoBox(colorScheme),
      ],
    );
  }

  Widget _buildLocationStatus(
    ColorScheme colorScheme,
    LocationChannelState locationState,
  ) {
    final isEnabled = locationState.permissionState == LocationPermissionState.authorized;
    final statusColor = isEnabled ? BitchatColors.locationGreen : Colors.orange;
    final statusText = isEnabled ? 'Location enabled' : 'Location disabled';
    final statusIcon = isEnabled ? Icons.location_on : Icons.location_off;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
          if (!isEnabled) ...[
            const Spacer(),
            TextButton(
              onPressed: () {
                ref.read(locationChannelManagerProvider.notifier).enableLocationChannels();
              },
              child: const Text(
                'Enable',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionPrompt(
    ColorScheme colorScheme,
    LocationChannelState locationState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.location_off,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Location access required',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enable location to see geohash channels for your area',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(locationChannelManagerProvider.notifier).enableLocationChannels();
            },
            icon: const Icon(Icons.location_on),
            label: const Text('Enable Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BitchatColors.locationGreen,
              foregroundColor: Colors.white,
            ),
          ),
          if (locationState.permissionState == LocationPermissionState.restricted) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ref.read(locationChannelManagerProvider.notifier).openAppSettings();
              },
              child: const Text(
                'Open Settings',
                style: TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualTab(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter geohash or coordinates',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Formats: geohash (e.g., u4pruq) or lat,lng (e.g., -34.6037,-58.3816)',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _manualInputController,
            decoration: InputDecoration(
              hintText: 'Enter geohash or coordinates...',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                color: colorScheme.onSurface.withOpacity(0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: IconButton(
                onPressed: _handleManualInput,
                icon: Icon(Icons.arrow_forward, color: colorScheme.primary),
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
            onSubmitted: (_) => _handleManualInput(),
          ),
          const SizedBox(height: 24),

          // Quick presets
          Text(
            'Quick presets',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip(colorScheme, 'Buenos Aires', '-34.6037,-58.3816'),
              _buildPresetChip(colorScheme, 'Madrid', '40.4168,-3.7038'),
              _buildPresetChip(colorScheme, 'NYC', '40.7128,-74.0060'),
              _buildPresetChip(colorScheme, 'Tokyo', '35.6762,139.6503'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(ColorScheme colorScheme, String label, String coords) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
      onPressed: () {
        _manualInputController.text = coords;
        _handleManualInput();
      },
      backgroundColor: colorScheme.surfaceVariant,
    );
  }

  Widget _buildMapTab(ColorScheme colorScheme) {
    // Default center (Buenos Aires)
    final defaultCenter = LatLng(-34.6037, -58.3816);
    final center = _teleportLocation ?? defaultCenter;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Tap on the map to select a location',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 10,
                  onTap: (tapPosition, point) => _handleMapTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.bitchat.app',
                  ),
                  if (_teleportLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _teleportLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              // Selected location info
              if (_teleportGeohash != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '#$_teleportGeohash',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: BitchatColors.locationGreen,
                                ),
                              ),
                              if (_teleportLocation != null)
                                Text(
                                  '${_teleportLocation!.latitude.toStringAsFixed(4)}, ${_teleportLocation!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _handleTeleportConfirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BitchatColors.locationGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'Teleport',
                            style: TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelOption(
    ColorScheme colorScheme, {
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.12)
                : colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.5) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(isSelected ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: isSelected ? color : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBox(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mesh broadcasts to all nearby Bluetooth devices. '
              'Location channels connect you with people in your area.',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLevel(GeohashChannelLevel level) {
    switch (level) {
      case GeohashChannelLevel.region:
        return Icons.public;
      case GeohashChannelLevel.province:
        return Icons.map;
      case GeohashChannelLevel.city:
        return Icons.location_city;
      case GeohashChannelLevel.neighborhood:
        return Icons.home_work;
      case GeohashChannelLevel.block:
        return Icons.apartment;
      case GeohashChannelLevel.building:
        return Icons.home;
    }
  }
}

/// Shows the location channels sheet.
void showLocationChannelsSheet(
  BuildContext context, {
  String? currentGeohash,
  String? selectedChannel,
  required ValueChanged<String?> onChannelSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LocationChannelsSheet(
      selectedChannel: selectedChannel,
      onChannelSelected: onChannelSelected,
    ),
  );
}
