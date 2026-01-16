import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Status badges for the ChatScreen header.
/// Matches Android implementation (ChatHeader.kt) for cross-platform parity.
///
/// Includes:
/// - LocationBadge: Shows #mesh (blue) or #geohash (green)
/// - TorStatusDot: 8dp colored dot indicating Tor connection status
/// - PoWStatusBadge: Security icon indicating PoW readiness

// =============================================================================
// CONSTANTS
// =============================================================================

/// iOS blue color for mesh channel badge.
const Color _meshBadgeColor = Color(0xFF007AFF);

/// iOS green color for geohash channel badge (future use).
const Color _geohashBadgeColor = Color(0xFF34C759);

/// Tor status colors (matching Android TorStatusDot).
const Color _torConnectedColor = Color(0xFF34C759); // Green - connected
const Color _torBootstrappingColor = Color(0xFFFF9500); // Orange - bootstrapping
const Color _torErrorColor = Color(0xFFFF3B30); // Red - error

/// PoW status colors (matching Android PoWStatusIndicator).
const Color _powReadyColor = Color(0xFF34C759); // Green - ready
const Color _powMiningColor = Color(0xFFFF9500); // Orange - mining

/// SharedPreferences keys for status settings.
const String _keyTorEnabled = 'tor_enabled';
const String _keyPoWEnabled = 'pow_enabled';

// =============================================================================
// LOCATION BADGE
// =============================================================================

/// Badge showing the current location channel (#mesh or #geohash).
///
/// - Default: #mesh (blue)
/// - With geohash: #<geohash> (green)
class LocationBadge extends StatelessWidget {
  /// The current geohash location (if available).
  /// If null, shows #mesh.
  final String? geohash;

  /// Called when the badge is tapped.
  final VoidCallback? onTap;

  const LocationBadge({
    super.key,
    this.geohash,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGeohash = geohash != null && geohash!.isNotEmpty;
    final channelText = isGeohash ? '#$geohash' : '#mesh';
    final badgeColor = isGeohash ? _geohashBadgeColor : _meshBadgeColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: badgeColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          channelText,
          style: TextStyle(
            color: badgeColor,
            fontFamily: 'monospace',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TOR STATUS DOT
// =============================================================================

/// Tor connection status.
enum TorStatus {
  /// Tor is disabled in settings.
  disabled,

  /// Tor is connected and working.
  connected,

  /// Tor is bootstrapping/connecting.
  bootstrapping,

  /// Tor encountered an error.
  error,
}

/// Provider for Tor enabled status from SharedPreferences.
final torEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyTorEnabled) ?? false;
});

/// 8dp colored dot indicating Tor connection status.
///
/// - Green: Connected and working
/// - Orange: Bootstrapping/connecting
/// - Red: Error
/// - Hidden: Tor disabled in settings
class TorStatusDot extends ConsumerWidget {
  /// Current Tor connection status.
  /// Defaults to bootstrapping since Tor is not yet implemented.
  final TorStatus status;

  const TorStatusDot({
    super.key,
    this.status = TorStatus.bootstrapping,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final torEnabledAsync = ref.watch(torEnabledProvider);

    return torEnabledAsync.when(
      data: (enabled) {
        if (!enabled) {
          // Tor disabled - don't render anything
          return const SizedBox.shrink();
        }

        return Tooltip(
          message: _getTooltip(),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getColor(),
              boxShadow: [
                BoxShadow(
                  color: _getColor().withOpacity(0.5),
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Color _getColor() {
    switch (status) {
      case TorStatus.connected:
        return _torConnectedColor;
      case TorStatus.bootstrapping:
        return _torBootstrappingColor;
      case TorStatus.error:
        return _torErrorColor;
      case TorStatus.disabled:
        return Colors.transparent;
    }
  }

  String _getTooltip() {
    switch (status) {
      case TorStatus.connected:
        return 'Tor: Connected';
      case TorStatus.bootstrapping:
        return 'Tor: Connecting...';
      case TorStatus.error:
        return 'Tor: Error';
      case TorStatus.disabled:
        return 'Tor: Disabled';
    }
  }
}

// =============================================================================
// POW STATUS BADGE
// =============================================================================

/// PoW (Proof of Work) status.
enum PoWStatus {
  /// PoW is disabled in settings.
  disabled,

  /// PoW is ready and tokens are available.
  ready,

  /// PoW is mining new tokens.
  mining,
}

/// Provider for PoW enabled status from SharedPreferences.
final powEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_keyPoWEnabled) ?? false;
});

/// Security icon indicating PoW (Proof of Work) status.
///
/// - Green shield: Ready (tokens available)
/// - Orange shield (rotating): Mining in progress
/// - Hidden: PoW disabled in settings
class PoWStatusBadge extends ConsumerStatefulWidget {
  /// Current PoW status.
  /// Defaults to ready since mining is not yet implemented.
  final PoWStatus status;

  const PoWStatusBadge({
    super.key,
    this.status = PoWStatus.ready,
  });

  @override
  ConsumerState<PoWStatusBadge> createState() => _PoWStatusBadgeState();
}

class _PoWStatusBadgeState extends ConsumerState<PoWStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.status == PoWStatus.mining) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(PoWStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == PoWStatus.mining && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (widget.status != PoWStatus.mining &&
        _rotationController.isAnimating) {
      _rotationController.stop();
      _rotationController.reset();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final powEnabledAsync = ref.watch(powEnabledProvider);

    return powEnabledAsync.when(
      data: (enabled) {
        if (!enabled) {
          // PoW disabled - don't render anything
          return const SizedBox.shrink();
        }

        final color = widget.status == PoWStatus.mining
            ? _powMiningColor
            : _powReadyColor;

        final icon = Icon(
          Icons.security,
          size: 12,
          color: color,
        );

        return Tooltip(
          message: _getTooltip(),
          child: widget.status == PoWStatus.mining
              ? RotationTransition(
                  turns: _rotationController,
                  child: icon,
                )
              : icon,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _getTooltip() {
    switch (widget.status) {
      case PoWStatus.ready:
        return 'PoW: Ready';
      case PoWStatus.mining:
        return 'PoW: Mining...';
      case PoWStatus.disabled:
        return 'PoW: Disabled';
    }
  }
}

// =============================================================================
// STATUS BADGES ROW
// =============================================================================

/// A row of status badges for the ChatScreen header.
/// Combines LocationBadge, TorStatusDot, and PoWStatusBadge.
class StatusBadgesRow extends StatelessWidget {
  /// Current geohash for location badge (if available).
  final String? geohash;

  /// Called when location badge is tapped.
  final VoidCallback? onLocationTap;

  /// Current Tor connection status.
  final TorStatus torStatus;

  /// Current PoW status.
  final PoWStatus powStatus;

  const StatusBadgesRow({
    super.key,
    this.geohash,
    this.onLocationTap,
    this.torStatus = TorStatus.bootstrapping,
    this.powStatus = PoWStatus.ready,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LocationBadge(
          geohash: geohash,
          onTap: onLocationTap,
        ),
        const SizedBox(width: 6),
        TorStatusDot(status: torStatus),
        const SizedBox(width: 4),
        PoWStatusBadge(status: powStatus),
        const SizedBox(width: 4),
      ],
    );
  }
}
