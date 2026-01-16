import 'package:flutter/material.dart';
import 'package:bitchat/features/mesh/peer_manager.dart';
import 'package:bitchat/ui/theme/bitchat_colors.dart';

/// Sidebar content widget displaying channels and peers.
/// This is the content portion extracted from PeerListSheet for use in
/// the responsive sidebar.
class NetworkSidebarContent extends StatelessWidget {
  /// List of peers to display
  final List<PeerInfo> peers;

  /// Currently selected private chat peer (can be null)
  final String? selectedPrivatePeerId;

  /// Callback when a peer is tapped (to start private chat)
  final ValueChanged<String>? onPeerTap;

  /// Callback when a peer's verify button is pressed
  final ValueChanged<String>? onVerifyTap;

  /// Callback when a peer's block button is pressed
  final ValueChanged<String>? onBlockTap;

  /// List of available channels
  final List<String> channels;

  /// Currently selected channel (null for mesh)
  final String? selectedChannel;

  /// Callback when a channel is selected
  final ValueChanged<String?> onChannelTap;

  /// Current geohash for location channel (null means #mesh mode)
  final String? currentGeohash;

  const NetworkSidebarContent({
    super.key,
    required this.peers,
    this.selectedPrivatePeerId,
    this.onPeerTap,
    this.onVerifyTap,
    this.onBlockTap,
    this.channels = const [],
    this.selectedChannel,
    required this.onChannelTap,
    this.currentGeohash,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),
        // Channels section - always show (mesh is always available)
        _buildChannelsSection(colorScheme, isDark),

        // Peers section
        _buildPeersSection(colorScheme, isDark),
      ],
    );
  }

  /// Builds the channels section with iOS-style colors.
  Widget _buildChannelsSection(ColorScheme colorScheme, bool isDark) {
    // Count active peers for mesh channel
    final activePeerCount = peers.where((p) => p.isConnected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                'CHANNELS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface.withOpacity(0.5),
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              if (activePeerCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: BitchatColors.meshBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activePeerCount online',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: BitchatColors.meshBlue,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Mesh channel (always available) - iOS blue
        _buildChannelTile(
          colorScheme,
          label: '#mesh',
          subtitle: 'Bluetooth broadcast',
          icon: Icons.bluetooth,
          iconColor: BitchatColors.meshBlue,
          isSelected: selectedChannel == null && currentGeohash == null,
          peerCount: activePeerCount,
          onTap: () => onChannelTap(null),
        ),

        // Location channel (if geohash available) - green
        if (currentGeohash != null)
          _buildChannelTile(
            colorScheme,
            label: '#${currentGeohash!.substring(0, currentGeohash!.length.clamp(0, 6))}',
            subtitle: 'Location channel',
            icon: Icons.location_on,
            iconColor: BitchatColors.locationGreen,
            isSelected: selectedChannel == currentGeohash,
            peerCount: null, // Location peers count not implemented yet
            onTap: () => onChannelTap(currentGeohash),
          ),

        // Custom channels
        ...channels.map(
          (channel) => _buildChannelTile(
            colorScheme,
            label: '#$channel',
            subtitle: null,
            icon: Icons.tag,
            iconColor: colorScheme.primary,
            isSelected: selectedChannel == channel,
            peerCount: null,
            onTap: () => onChannelTap(channel),
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds a single channel tile with iOS-style design.
  Widget _buildChannelTile(
    ColorScheme colorScheme, {
    required String label,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    int? peerCount,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? iconColor.withOpacity(0.12) : null,
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(color: iconColor.withOpacity(0.3), width: 1)
            : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(isSelected ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
        title: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: isSelected ? iconColor : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (peerCount != null && peerCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$peerCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              )
            : null,
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: BitchatColors.iosGreenDark,
                size: 20,
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Builds the peers section.
  Widget _buildPeersSection(ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                'PEOPLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: colorScheme.onSurface.withOpacity(0.5),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${peers.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),

        // Peers list or empty state
        if (peers.isEmpty)
          _buildEmptyState(colorScheme)
        else
          ...peers.map(
            (peer) => _buildPeerTile(colorScheme, isDark, peer),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  /// Builds the empty state when no peers are connected.
  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.person_off,
            size: 48,
            color: colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No one connected',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.6),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find people nearby or invite friends',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds a single peer tile.
  Widget _buildPeerTile(ColorScheme colorScheme, bool isDark, PeerInfo peer) {
    final isSelected = selectedPrivatePeerId == peer.id;
    final isConnected = peer.isConnected;

    // Get display name - truncate if too long
    final displayName = peer.name.length > 16
        ? '${peer.name.substring(0, 16)}...'
        : peer.name;

    // RSSI-based signal strength
    final signalStrength = _getSignalStrength(peer.rssi);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : (isDark
                ? colorScheme.surfaceVariant.withOpacity(0.3)
                : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onPeerTap != null ? () => onPeerTap!(peer.id) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main peer info row
              Row(
                children: [
                  // Avatar with verification status
                  _buildAvatar(colorScheme, peer),

                  const SizedBox(width: 12),

                  // Name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Display name with connection indicator
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                  color: colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (peer.isVerifiedName) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                size: 14,
                                color: Colors.green,
                              ),
                            ],
                            const SizedBox(width: 6),
                            // Connection status indicator
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isConnected
                                    ? Colors.green
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 2),

                        // Peer ID (truncated)
                        Text(
                          peer.id.length > 16
                              ? '${peer.id.substring(0, 16)}...'
                              : peer.id,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Signal strength indicator
                  if (peer.rssi != null)
                    _buildSignalIndicator(colorScheme, signalStrength),

                  // More options button
                  _buildPeerActionsMenu(colorScheme, peer),
                ],
              ),

              // Additional info row (RSSI, transport, last seen)
              if (!isConnected)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.offline_bolt,
                        size: 12,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Last seen: ${_formatLastSeen(peer.lastSeen)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.5),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the peer avatar with verification status overlay.
  Widget _buildAvatar(ColorScheme colorScheme, PeerInfo peer) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: peer.isVerifiedName
              ? Colors.green
              : colorScheme.outline.withOpacity(0.3),
          width: peer.isVerifiedName ? 2 : 1,
        ),
      ),
      child: Center(
        child: Text(
          peer.name.isNotEmpty ? peer.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// Builds the signal strength indicator (RSSI bars).
  Widget _buildSignalIndicator(ColorScheme colorScheme, int signalStrength) {
    final bars = List.generate(4, (index) {
      final isActive = index < signalStrength;
      return Container(
        width: 3,
        height: 4 + (index * 3),
        margin: const EdgeInsets.only(right: 1),
        decoration: BoxDecoration(
          color: isActive
              ? (signalStrength >= 3
                  ? Colors.green
                  : (signalStrength >= 2
                      ? Colors.orange
                      : Colors.red))
              : colorScheme.outline.withOpacity(0.3),
          borderRadius: BorderRadius.circular(1),
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.reversed.toList(),
      ),
    );
  }

  /// Builds the peer actions menu (verify, block, etc.).
  Widget _buildPeerActionsMenu(ColorScheme colorScheme, PeerInfo peer) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: colorScheme.onSurface.withOpacity(0.6),
        size: 18,
      ),
      tooltip: 'Peer actions',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 28,
        minHeight: 28,
      ),
      onSelected: (action) {
        switch (action) {
          case 'verify':
            onVerifyTap?.call(peer.id);
            break;
          case 'block':
            onBlockTap?.call(peer.id);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'verify',
          child: Row(
            children: [
              Icon(
                peer.isVerifiedName ? Icons.verified_user : Icons.verified,
                size: 18,
                color: peer.isVerifiedName ? Colors.green : colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                peer.isVerifiedName ? 'Verified' : 'Verify',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'block',
          child: Row(
            children: [
              const Icon(Icons.block, size: 18, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Block',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Converts RSSI value to signal strength (0-4).
  int _getSignalStrength(int? rssi) {
    if (rssi == null) return 0;

    // RSSI ranges (typical BLE values)
    if (rssi >= -50) return 4; // Excellent
    if (rssi >= -60) return 3; // Good
    if (rssi >= -70) return 2; // Fair
    if (rssi >= -80) return 1; // Weak
    return 0; // Very weak or disconnected
  }

  /// Formats the last seen timestamp.
  String _formatLastSeen(int lastSeenMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = now - lastSeenMs;

    if (diffMs < 60000) return 'Just now';
    if (diffMs < 3600000) return '${(diffMs / 60000).floor()}m ago';
    if (diffMs < 86400000) return '${(diffMs / 3600000).floor()}h ago';
    return '${(diffMs / 86400000).floor()}d ago';
  }
}
