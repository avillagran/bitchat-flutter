import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bitchat/features/debug/debug_settings_provider.dart';
import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';
import 'package:bitchat/ui/theme/bitchat_colors.dart';

/// Helper functions for GCS parameter calculation (matching Android GCSFilter)
int _deriveP(double targetFprPercent) {
  final fpr = (targetFprPercent / 100.0).clamp(0.000001, 0.25);
  return (math.log(1.0 / fpr) / math.ln2).ceil().clamp(1, 20);
}

int _estimateMaxElements(int maxBytes, int p) {
  final bits = (maxBytes * 8).clamp(8, maxBytes * 8);
  final perElement = (p + 2).clamp(3, p + 2);
  return (bits ~/ perElement).clamp(1, bits);
}

/// Debug Settings Sheet - Advanced BLE/mesh configuration and monitoring.
/// Matches Android DebugSettingsSheet functionality.
class DebugSettingsSheet extends ConsumerWidget {
  const DebugSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final debugState = ref.watch(debugSettingsProvider);
    final meshService = ref.watch(meshServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.bug_report, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Debug Tools',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontFamily: 'monospace',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: colorScheme.primary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Scrollable content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Verbose Logging Toggle
                      _buildToggleCard(
                        context,
                        icon: Icons.text_snippet,
                        title: 'Verbose Logging',
                        subtitle: 'Enable detailed debug logs',
                        value: debugState.verboseLoggingEnabled,
                        onChanged: (v) => ref
                            .read(debugSettingsProvider.notifier)
                            .setVerboseLogging(v),
                      ),

                      const SizedBox(height: 16),

                      // Bluetooth Roles Section
                      _buildSectionTitle(context, 'Bluetooth Roles'),
                      _buildCard(
                        context,
                        child: Builder(builder: (context) {
                          // Calculate live connection counts
                          final serverCount = debugState.connectedDevices
                              .where((d) =>
                                  d.connectionType == ConnectionType.gattServer)
                              .length;
                          final clientCount = debugState.connectedDevices
                              .where((d) =>
                                  d.connectionType == ConnectionType.gattClient)
                              .length;
                          final overallCount =
                              debugState.connectedDevices.length;

                          return Column(
                            children: [
                              _buildToggleRow(
                                context,
                                title: 'GATT Server',
                                subtitle: 'Advertise as peripheral',
                                value: debugState.gattServerEnabled,
                                onChanged: (v) => ref
                                    .read(debugSettingsProvider.notifier)
                                    .setGattServerEnabled(v),
                              ),
                              _buildConnectionCountRow(
                                context,
                                current: serverCount,
                                max: debugState.maxServerConnections,
                              ),
                              _buildSliderRow(
                                context,
                                title: 'Max Server Connections',
                                value:
                                    debugState.maxServerConnections.toDouble(),
                                min: 1,
                                max: 32,
                                onChanged: (v) => ref
                                    .read(debugSettingsProvider.notifier)
                                    .setMaxServerConnections(v.round()),
                              ),
                              const Divider(),
                              _buildToggleRow(
                                context,
                                title: 'GATT Client',
                                subtitle: 'Scan and connect to peripherals',
                                value: debugState.gattClientEnabled,
                                onChanged: (v) => ref
                                    .read(debugSettingsProvider.notifier)
                                    .setGattClientEnabled(v),
                              ),
                              _buildConnectionCountRow(
                                context,
                                current: clientCount,
                                max: debugState.maxClientConnections,
                              ),
                              _buildSliderRow(
                                context,
                                title: 'Max Client Connections',
                                value:
                                    debugState.maxClientConnections.toDouble(),
                                min: 1,
                                max: 32,
                                onChanged: (v) => ref
                                    .read(debugSettingsProvider.notifier)
                                    .setMaxClientConnections(v.round()),
                              ),
                              const Divider(),
                              _buildConnectionCountRow(
                                context,
                                current: overallCount,
                                max: debugState.maxConnectionsOverall,
                                label: 'Overall',
                              ),
                              _buildSliderRow(
                                context,
                                title: 'Max Overall Connections',
                                value:
                                    debugState.maxConnectionsOverall.toDouble(),
                                min: 1,
                                max: 32,
                                onChanged: (v) => ref
                                    .read(debugSettingsProvider.notifier)
                                    .setMaxConnectionsOverall(v.round()),
                              ),
                            ],
                          );
                        }),
                      ),

                      const SizedBox(height: 16),

                      // MTU Settings Section
                      _buildSectionTitle(context, 'MTU Settings'),
                      _buildCard(
                        context,
                        child: Column(
                          children: [
                            _buildToggleRow(
                              context,
                              title: 'Request MTU',
                              subtitle: 'Negotiate MTU on connect',
                              value: debugState.requestMtuEnabled,
                              onChanged: (v) => ref
                                  .read(debugSettingsProvider.notifier)
                                  .setRequestMtuEnabled(v),
                            ),
                            _buildSliderRow(
                              context,
                              title: 'MTU Size',
                              value: debugState.requestedMtuSize.toDouble(),
                              min: 23,
                              max: 517,
                              enabled: debugState.requestMtuEnabled,
                              onChanged: (v) => ref
                                  .read(debugSettingsProvider.notifier)
                                  .setRequestedMtuSize(v.round()),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Packet Relay Section
                      _buildSectionTitle(context, 'Packet Relay'),
                      _buildCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildToggleRow(
                              context,
                              title: 'Enable Relay',
                              subtitle: 'Forward packets to other peers',
                              value: debugState.packetRelayEnabled,
                              onChanged: (v) => ref
                                  .read(debugSettingsProvider.notifier)
                                  .setPacketRelayEnabled(v),
                            ),
                            const Divider(),
                            // Graph mode selector (matching Android FilterChip row)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  _buildModeChip(
                                    context,
                                    label: 'Overall',
                                    isSelected: debugState.graphMode ==
                                        GraphMode.overall,
                                    onTap: () => ref
                                        .read(debugSettingsProvider.notifier)
                                        .setGraphMode(GraphMode.overall),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModeChip(
                                    context,
                                    label: 'Per Device',
                                    icon: Icons.devices,
                                    isSelected: debugState.graphMode ==
                                        GraphMode.perDevice,
                                    onTap: () => ref
                                        .read(debugSettingsProvider.notifier)
                                        .setGraphMode(GraphMode.perDevice),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildModeChip(
                                    context,
                                    label: 'Per Peer',
                                    icon: Icons.settings_ethernet,
                                    isSelected: debugState.graphMode ==
                                        GraphMode.perPeer,
                                    onTap: () => ref
                                        .read(debugSettingsProvider.notifier)
                                        .setGraphMode(GraphMode.perPeer),
                                  ),
                                ],
                              ),
                            ),
                            // Incoming graph
                            _buildRelayGraph(
                              context,
                              title: 'Incoming',
                              series: debugState.relayStats.incomingSeries,
                              total: debugState.relayStats.incomingTotal,
                              color: const Color(0xFF00C851),
                            ),
                            const SizedBox(height: 8),
                            // Outgoing graph
                            _buildRelayGraph(
                              context,
                              title: 'Outgoing',
                              series: debugState.relayStats.outgoingSeries,
                              total: debugState.relayStats.outgoingTotal,
                              color: const Color(0xFFFF9500),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sync Settings Section
                      _buildSectionTitle(context, 'Sync Settings'),
                      _buildCard(
                        context,
                        child: Column(
                          children: [
                            _buildSliderRow(
                              context,
                              title: 'Max Packets per Sync',
                              value: debugState.seenPacketCapacity.toDouble(),
                              min: 10,
                              max: 1000,
                              onChanged: (v) => ref
                                  .read(debugSettingsProvider.notifier)
                                  .setSeenPacketCapacity(v.round()),
                            ),
                            _buildSliderRow(
                              context,
                              title: 'Max GCS Filter Size (bytes)',
                              value: debugState.gcsMaxBytes.toDouble(),
                              min: 128,
                              max: 1024,
                              onChanged: (v) => ref
                                  .read(debugSettingsProvider.notifier)
                                  .setGcsMaxBytes(v.round()),
                            ),
                            _buildSliderRow(
                              context,
                              title: 'Target FPR %',
                              value: debugState.gcsFprPercent,
                              min: 0.1,
                              max: 5.0,
                              divisions: 49,
                              formatValue: (v) => '${v.toStringAsFixed(1)}%',
                              onChanged: (v) => ref
                                  .read(debugSettingsProvider.notifier)
                                  .setGcsFprPercent(v),
                            ),
                            // Derived GCS parameters (matching Android)
                            Builder(builder: (context) {
                              final p = _deriveP(debugState.gcsFprPercent);
                              final nmax = _estimateMaxElements(
                                  debugState.gcsMaxBytes, p);
                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: Text(
                                  'derived p=$p, nmax≈$nmax',
                                  style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.7),
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Connected Devices Section
                      _buildSectionTitle(context, 'Connected Devices'),
                      _buildCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Local device ID
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Text(
                                'Our device: ${meshService.myPeerID}',
                                style: TextStyle(
                                  color: colorScheme.onSurface.withOpacity(0.7),
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (debugState.connectedDevices.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text(
                                  'none',
                                  style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.5),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              )
                            else
                              ...debugState.connectedDevices.map(
                                (d) => _buildDeviceRow(
                                  context,
                                  d,
                                  onDisconnect: () {
                                    meshService
                                        .disconnectDevice(d.deviceAddress);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Recent Scan Results Section
                      _buildSectionTitle(context, 'Recent Scan Results'),
                      _buildCard(
                        context,
                        child: debugState.scanResults.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'none',
                                  style: TextStyle(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.5),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              )
                            : Column(
                                children: debugState.scanResults
                                    .take(10)
                                    .map((r) => _buildScanResultRow(
                                          context,
                                          r,
                                          onConnect: () {
                                            meshService.connectToDevice(
                                                r.deviceAddress);
                                          },
                                        ))
                                    .toList(),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // Debug Console Section
                      _buildSectionTitle(
                        context,
                        'Debug Console',
                        trailing: TextButton(
                          onPressed: () => ref
                              .read(debugSettingsProvider.notifier)
                              .clearDebugMessages(),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                      _buildCard(
                        context,
                        child: Container(
                          height: 200,
                          padding: const EdgeInsets.all(8),
                          child: debugState.debugMessages.isEmpty
                              ? Center(
                                  child: Text(
                                    'No debug messages',
                                    style: TextStyle(
                                      color: colorScheme.onSurface
                                          .withOpacity(0.5),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  reverse: true,
                                  itemCount: debugState.debugMessages.length,
                                  itemBuilder: (context, index) {
                                    final msg = debugState.debugMessages[index];
                                    return _buildLogRow(context, msg);
                                  },
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mesh Info Section
                      _buildSectionTitle(context, 'Mesh Service Info'),
                      _buildCard(
                        context,
                        child: Column(
                          children: [
                            _buildInfoRow(
                                context, 'My Peer ID', meshService.myPeerID),
                            _buildInfoRow(
                              context,
                              'Status',
                              meshService.isActive ? 'Active' : 'Inactive',
                              valueColor: meshService.isActive
                                  ? BitchatColors.rssiExcellent
                                  : BitchatColors.rssiPoor,
                            ),
                            _buildInfoRow(
                              context,
                              'Connected Peers',
                              '${meshService.getPeerCount()}',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Copy Debug Info Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.copy, color: colorScheme.primary),
                          label: Text(
                            'Copy Debug Summary',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colorScheme.primary),
                            padding: const EdgeInsets.all(16),
                          ),
                          onPressed: () {
                            final summary = ref
                                .read(debugSettingsProvider.notifier)
                                .getDebugSummary();
                            Clipboard.setData(ClipboardData(text: summary));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Debug summary copied'),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: child,
    );
  }

  Widget _buildToggleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildCard(
      context,
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    int? divisions,
    bool enabled = true,
    String Function(double)? formatValue,
    required ValueChanged<double> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = formatValue?.call(value) ?? value.round().toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: enabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withOpacity(0.4),
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                displayValue,
                style: TextStyle(
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.primary.withOpacity(0.4),
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            onChanged: enabled ? onChanged : null,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCountRow(
    BuildContext context, {
    required int current,
    required int max,
    String? label,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayText = label != null
        ? '$label: $current / $max connections'
        : '$current / $max connections';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Text(
        displayText,
        style: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.7),
          fontFamily: 'monospace',
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildModeChip(
    BuildContext context, {
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurface.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.7),
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelayGraph(
    BuildContext context, {
    required String title,
    required List<int> series,
    required int total,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    const barCount = 60;
    const graphHeight = 40.0;

    // Normalize series to fit graph
    final maxVal = series.isEmpty ? 0 : series.reduce(math.max);
    final normalizedMax = maxVal > 0 ? maxVal : 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$title: $total',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: graphHeight,
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, graphHeight),
              painter: _BarGraphPainter(
                series: series,
                maxValue: normalizedMax,
                barCount: barCount,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.primary,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(
    BuildContext context,
    ConnectedDevice device, {
    VoidCallback? onDisconnect,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final roleLabel = device.connectionType == ConnectionType.gattServer
        ? 'Server'
        : 'Client';
    final directSuffix = device.isDirectConnection ? ' (direct)' : '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${device.peerID ?? 'Unknown'} • ${device.deviceAddress}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${device.nickname ?? ''} • ${device.rssi != null ? '${device.rssi} dBm' : '?'} • $roleLabel$directSuffix',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (onDisconnect != null)
            GestureDetector(
              onTap: onDisconnect,
              child: const Text(
                'Disconnect',
                style: TextStyle(
                  color: Color(0xFFBF1A1A),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanResultRow(
    BuildContext context,
    DebugScanResult result, {
    VoidCallback? onConnect,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.peerID ?? 'Unknown'} • ${result.deviceAddress}',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${result.rssi} dBm',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (onConnect != null)
            GestureDetector(
              onTap: onConnect,
              child: const Text(
                'Connect',
                style: TextStyle(
                  color: Color(0xFF00C851),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogRow(BuildContext context, DebugMessage msg) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.formattedTime,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.5),
              fontFamily: 'monospace',
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _getLogTypeColor(msg.type).withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              msg.type.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: _getLogTypeColor(msg.type),
                fontFamily: 'monospace',
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              msg.message,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? colorScheme.primary,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -50) return BitchatColors.rssiExcellent;
    if (rssi >= -70) return BitchatColors.rssiGood;
    if (rssi >= -85) return BitchatColors.rssiFair;
    return BitchatColors.rssiPoor;
  }

  Color _getLogTypeColor(DebugMessageType type) {
    switch (type) {
      case DebugMessageType.system:
        return Colors.blue;
      case DebugMessageType.peer:
        return Colors.green;
      case DebugMessageType.packet:
        return Colors.orange;
      case DebugMessageType.relay:
        return Colors.purple;
      case DebugMessageType.error:
        return Colors.red;
    }
  }
}

/// Shows the debug settings sheet as a modal bottom sheet.
void showDebugSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const DebugSettingsSheet(),
  );
}

/// Custom painter for drawing bar graphs in the packet relay section.
class _BarGraphPainter extends CustomPainter {
  final List<int> series;
  final int maxValue;
  final int barCount;
  final Color color;

  _BarGraphPainter({
    required this.series,
    required this.maxValue,
    required this.barCount,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final barWidth = size.width / barCount;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw baseline
    final baselinePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      baselinePaint,
    );

    // Pad series to barCount length (right-aligned)
    final paddedSeries = List<int>.filled(barCount, 0);
    final offset = barCount - series.length;
    for (var i = 0; i < series.length && i < barCount; i++) {
      if (offset + i >= 0) {
        paddedSeries[offset + i] = series[i];
      }
    }

    // Draw bars
    for (var i = 0; i < barCount; i++) {
      final value = paddedSeries[i];
      if (value <= 0) continue;

      final ratio = (value / maxValue).clamp(0.0, 1.0);
      final barHeight = (size.height * ratio).clamp(1.0, size.height);

      canvas.drawRect(
        Rect.fromLTWH(
          i * barWidth,
          size.height - barHeight,
          barWidth - 1,
          barHeight,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarGraphPainter oldDelegate) {
    return oldDelegate.series != series ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.color != color;
  }
}
