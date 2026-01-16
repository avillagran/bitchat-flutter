import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';
import 'package:bitchat/ui/widgets/debug_settings_sheet.dart';

/// App version constants
const String _appVersion = '1.0.0';

/// Theme preference enum matching Android
enum ThemePreference { system, light, dark }

/// Provider for theme preference
final themePreferenceProvider =
    StateNotifierProvider<ThemePreferenceNotifier, ThemePreference>((ref) {
  return ThemePreferenceNotifier();
});

/// Notifier for theme preference
class ThemePreferenceNotifier extends StateNotifier<ThemePreference> {
  ThemePreferenceNotifier() : super(ThemePreference.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString('theme_preference') ?? 'system';
    state = ThemePreference.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ThemePreference.system,
    );
  }

  Future<void> set(ThemePreference pref) async {
    state = pref;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preference', pref.name);
  }
}

/// Callback type for showing Nostr account management
typedef OnShowNostrAccount = void Function();

/// About sheet showing app information and settings.
/// Matches Android AboutSheet functionality with Apple-like design.
class AboutSheet extends ConsumerStatefulWidget {
  final OnShowNostrAccount? onShowNostrAccount;

  const AboutSheet({
    super.key,
    this.onShowNostrAccount,
  });

  @override
  ConsumerState<AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends ConsumerState<AboutSheet> {
  bool _backgroundEnabled = true;
  bool _powEnabled = false;
  int _powDifficulty = 16;
  bool _torEnabled = false;

  // Tor status simulation (in real app, would come from Tor service)
  bool _torRunning = false;
  int _torBootstrapPercent = 0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundEnabled = prefs.getBool('background_enabled') ?? true;
      _powEnabled = prefs.getBool('pow_enabled') ?? false;
      _powDifficulty = prefs.getInt('pow_difficulty') ?? 16;
      _torEnabled = prefs.getBool('tor_enabled') ?? false;
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  String _estimateMiningTime(int difficulty) {
    if (difficulty == 0) return 'instant';
    if (difficulty <= 8) return '<1s';
    if (difficulty <= 12) return '~1s';
    if (difficulty <= 16) return '~5s';
    if (difficulty <= 20) return '~30s';
    if (difficulty <= 24) return '~5min';
    return '>30min';
  }

  String _getPowDescription(int difficulty) {
    if (difficulty == 0) return 'No proof of work required';
    if (difficulty <= 8) return 'Very low - minimal spam protection';
    if (difficulty <= 12) return 'Low - basic spam protection';
    if (difficulty <= 16) return 'Medium - good balance';
    if (difficulty <= 20) return 'High - strong spam protection';
    if (difficulty <= 24) return 'Very high - slow message sending';
    return 'Extreme - may take minutes per message';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final meshService = ref.watch(meshServiceProvider);
    final themePref = ref.watch(themePreferenceProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // Close button row
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: colorScheme.onSurface),
            ),
          ),

          // Scrollable content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // Header Section
                _buildHeader(colorScheme),

                const SizedBox(height: 20),

                // Features Section
                _buildSectionLabel(context, 'FEATURES'),
                _buildFeaturesCard(context, colorScheme),

                const SizedBox(height: 20),

                // Theme Section
                _buildSectionLabel(context, 'THEME'),
                _buildThemeCard(context, colorScheme, isDark, themePref),

                const SizedBox(height: 20),

                // Nostr Account Section
                if (widget.onShowNostrAccount != null) ...[
                  _buildSectionLabel(context, 'NOSTR ACCOUNT'),
                  _buildNostrAccountCard(context, colorScheme),
                  const SizedBox(height: 20),
                ],

                // Settings Section
                _buildSectionLabel(context, 'SETTINGS'),
                _buildSettingsCard(context, colorScheme, isDark, meshService),

                // PoW Difficulty Slider (when enabled)
                if (_powEnabled) ...[
                  const SizedBox(height: 12),
                  _buildPowSlider(context, colorScheme, isDark),
                ],

                // Tor Status (when enabled)
                if (_torEnabled) ...[
                  const SizedBox(height: 12),
                  _buildTorStatus(context, colorScheme, isDark),
                ],

                const SizedBox(height: 20),

                // Emergency Warning
                _buildEmergencyWarning(context, colorScheme),

                const SizedBox(height: 20),

                // Debug Settings Link
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      showDebugSettingsSheet(context);
                    },
                    child: Text(
                      'Debug Settings',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                // Footer
                Center(
                  child: Text(
                    'Made with ❤️ for the mesh',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.4),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          'bitchat',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontFamily: 'monospace',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'v$_appVersion',
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.5),
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Decentralized mesh chat',
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontFamily: 'monospace',
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 36, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _FeatureRow(
              icon: Icons.bluetooth,
              title: 'Offline Mesh',
              subtitle:
                  'Chat with nearby devices via Bluetooth LE without internet',
            ),
            Divider(
              height: 1,
              indent: 56,
              color: colorScheme.outline.withOpacity(0.12),
            ),
            _FeatureRow(
              icon: Icons.public,
              title: 'Online Geohash',
              subtitle:
                  'Connect with people in your area via Nostr relays',
            ),
            Divider(
              height: 1,
              indent: 56,
              color: colorScheme.outline.withOpacity(0.12),
            ),
            _FeatureRow(
              icon: Icons.lock,
              title: 'End-to-End Encrypted',
              subtitle:
                  'All messages are encrypted using the Noise protocol',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    ThemePreference themePref,
  ) {
    final notifier = ref.read(themePreferenceProvider.notifier);
    final activeColor = isDark ? const Color(0xFF32D74B) : const Color(0xFF248A3D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _ThemeChip(
                label: 'System',
                selected: themePref == ThemePreference.system,
                activeColor: activeColor,
                onTap: () => notifier.set(ThemePreference.system),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeChip(
                label: 'Light',
                selected: themePref == ThemePreference.light,
                activeColor: activeColor,
                onTap: () => notifier.set(ThemePreference.light),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeChip(
                label: 'Dark',
                selected: themePref == ThemePreference.dark,
                activeColor: activeColor,
                onTap: () => notifier.set(ThemePreference.dark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
    BluetoothMeshService meshService,
  ) {
    final activeColor = isDark ? const Color(0xFF32D74B) : const Color(0xFF248A3D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Background Mode Toggle
            _SettingsToggleRow(
              icon: Icons.bluetooth,
              title: 'Background Mode',
              subtitle: 'Keep mesh active when app is in background',
              value: _backgroundEnabled,
              activeColor: activeColor,
              onChanged: (value) {
                setState(() => _backgroundEnabled = value);
                _savePreference('background_enabled', value);
                if (value) {
                  meshService.start();
                } else {
                  meshService.stop();
                }
              },
            ),

            Divider(
              height: 1,
              indent: 56,
              color: colorScheme.outline.withOpacity(0.12),
            ),

            // Proof of Work Toggle
            _SettingsToggleRow(
              icon: Icons.speed,
              title: 'Proof of Work',
              subtitle: 'Add computational proof to reduce spam',
              value: _powEnabled,
              activeColor: activeColor,
              onChanged: (value) {
                setState(() => _powEnabled = value);
                _savePreference('pow_enabled', value);
              },
            ),

            Divider(
              height: 1,
              indent: 56,
              color: colorScheme.outline.withOpacity(0.12),
            ),

            // Tor Toggle (disabled for now - Tor not implemented in Flutter)
            _SettingsToggleRow(
              icon: Icons.security,
              title: 'Tor Network',
              subtitle: 'Route geohash traffic through Tor',
              value: _torEnabled,
              activeColor: activeColor,
              enabled: false, // Tor not available in Flutter yet
              onChanged: (value) {
                setState(() => _torEnabled = value);
                _savePreference('tor_enabled', value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowSlider(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final activeColor = isDark ? const Color(0xFF32D74B) : const Color(0xFF248A3D);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Difficulty',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$_powDifficulty bits • ${_estimateMiningTime(_powDifficulty)}',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: activeColor,
                thumbColor: activeColor,
                inactiveTrackColor: colorScheme.surfaceVariant,
              ),
              child: Slider(
                value: _powDifficulty.toDouble(),
                min: 0,
                max: 32,
                divisions: 32,
                onChanged: (value) {
                  setState(() => _powDifficulty = value.toInt());
                  _savePreference('pow_difficulty', value.toInt());
                },
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getPowDescription(_powDifficulty),
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.5),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNostrAccountCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: widget.onShowNostrAccount,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.lock,
                color: colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Keys',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View, export or import your Nostr identity',
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '>',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.3),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTorStatus(
    BuildContext context,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    // Determine status color based on Tor state
    final Color statusColor;
    if (_torRunning && _torBootstrapPercent >= 100) {
      statusColor = isDark ? const Color(0xFF32D74B) : const Color(0xFF248A3D);
    } else if (_torRunning) {
      statusColor = const Color(0xFFFF9500); // Orange for bootstrapping
    } else {
      statusColor = const Color(0xFFFF3B30); // Red for disconnected
    }

    final String statusText = _torRunning
        ? 'Connected ($_torBootstrapPercent%)'
        : 'Disconnected';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (!_torRunning) ...[
              const SizedBox(height: 8),
              Text(
                'Tor service not available in this build',
                style: TextStyle(
                  color: colorScheme.onSurface.withOpacity(0.5),
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyWarning(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning,
              color: colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Wipe',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Triple-tap the "bitchat" logo to immediately wipe all messages and reset the app.',
                    style: TextStyle(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feature row widget
class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme selection chip
class _ThemeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor
              : colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colorScheme.onSurface.withOpacity(0.8),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings toggle row
class _SettingsToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveOpacity = enabled ? 1.0 : 0.4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.primary.withOpacity(effectiveOpacity),
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colorScheme.onSurface.withOpacity(effectiveOpacity),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (!enabled) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(Coming soon)',
                        style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.6 * effectiveOpacity),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: Colors.white,
            activeTrackColor: activeColor,
          ),
        ],
      ),
    );
  }
}

/// Shows the about sheet as a modal bottom sheet.
void showAboutSheet(
  BuildContext context, {
  OnShowNostrAccount? onShowNostrAccount,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AboutSheet(
      onShowNostrAccount: onShowNostrAccount,
    ),
  );
}
