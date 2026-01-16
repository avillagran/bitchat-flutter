---
date: 2026-01-16T07:46:35-0300
session_name: general
researcher: claude
git_commit: 44f6c2d
branch: main
repository: bitchat-flutter
topic: "Responsive Sidebar Implementation and macOS BLE TCC Debugging"
tags: [sidebar, ui, macos, bluetooth, tcc, flutter]
status: in_progress
last_updated: 2026-01-16
last_updated_by: claude
type: implementation
---

# Handoff: Responsive Sidebar + macOS BLE TCC Crash

## Task(s)
| Task | Status |
|------|--------|
| Implement responsive "Your Network" sidebar | ✅ Completed |
| Fix Material widget error in sidebar | ✅ Completed |
| Fix "Tu Red" → "Your Network" text | ✅ Completed |
| Debug macOS BLE TCC crash | 🔴 Blocked |

**Previous handoff:** `thoughts/shared/handoffs/general/2026-01-16_07-30-00_macos-ble-fix-and-sidebar-request.md`

## Critical References
- `lib/ui/widgets/responsive_sidebar.dart` - New sidebar widget
- `lib/ui/widgets/network_sidebar_content.dart` - Sidebar content
- `~/.pub-cache/hosted/pub.dev/bluetooth_low_energy_darwin-6.0.0/darwin/Classes/MyCentralManager.swift:48` - **ROOT CAUSE**: `CBCentralManager()` created immediately on plugin registration

## Recent Changes
- `lib/ui/chat_screen.dart:357-371` - Wrapped NetworkSidebarContent in Material widget
- `lib/ui/chat_screen.dart:383` - Changed "Tu Red" to "Your Network"
- `lib/ui/widgets/responsive_sidebar.dart:441` - Added `decoration: TextDecoration.none` to fix underline
- `lib/ui/widgets/network_sidebar_content.dart:358` - Fixed `surfaceContainerHighest` → `surfaceVariant` for Flutter 3.19.5
- `run.sh:130-131` - Added global `tccutil reset BluetoothAlways` before bundle-specific reset

## Learnings

### 1. macOS TCC Crash Root Cause (CRITICAL)
The `bluetooth_low_energy_darwin` package creates `CBCentralManager()` IMMEDIATELY during Flutter plugin registration (`MyCentralManager.swift:48`). On macOS 14.x Sonoma, this triggers a TCC check that crashes the app BEFORE any Flutter code runs - even with:
- `NSBluetoothAlwaysUsageDescription` in Info.plist ✓
- `com.apple.security.device.bluetooth` entitlement ✓
- TCC permissions reset ✓

**This is a package-level bug** - the CBCentralManager should be lazily initialized, not created during plugin registration.

### 2. TCC Reset Commands
```bash
# Reset globally (this works)
tccutil reset BluetoothAlways

# Reset for bundle (also needed)
tccutil reset All com.bitchat.bitchat
```
Both are now in `run.sh:130-131`.

### 3. Flutter 3.19.5 Compatibility
`ColorScheme.surfaceContainerHighest` doesn't exist - use `surfaceVariant` instead.

## Post-Mortem

### What Worked
- Sidebar implementation with responsive breakpoints (desktop always visible, mobile swipe)
- Material widget wrap fixed ListTile error immediately
- TCC reset commands work when run manually before app launch
- App runs fine after manual `tccutil reset BluetoothAlways` + manual `open bitchat.app`

### What Failed
- **bluetooth_low_energy_darwin package eagerly creates CBCentralManager** during plugin registration, causing TCC crash before Flutter code can request authorization
- run.sh TCC reset runs BEFORE build but app still crashes because Flutter rebuilds and re-registers plugins after the reset timing window
- Cannot catch or prevent the crash from Dart code - it happens at native layer

### Key Decisions
- Decision: Use `surfaceVariant` instead of `surfaceContainerHighest`
  - Alternatives: Upgrade Flutter
  - Reason: Keep Flutter 3.19.5 compatibility

- Decision: Add both global BluetoothAlways reset AND bundle-specific reset to run.sh
  - Alternatives: Only bundle-specific
  - Reason: Global reset clears all cached denials, bundle-specific handles app-specific

## Artifacts
- `lib/ui/widgets/responsive_sidebar.dart` - NEW: Reusable responsive sidebar widget
- `lib/ui/widgets/network_sidebar_content.dart` - NEW: Sidebar content (channels + peers)
- `lib/ui/chat_screen.dart` - MODIFIED: Integrated sidebar
- `run.sh` - MODIFIED: TCC reset improvements

## Action Items & Next Steps

### 1. Fix macOS BLE TCC Crash (HIGH PRIORITY)
Options to investigate:
1. **Fork bluetooth_low_energy_darwin** and make CBCentralManager lazy-init
2. **Delay BLE initialization** - add a button/toggle to manually enable BLE after app starts
3. **Use different BLE package** - check if `flutter_blue_plus` has same issue
4. **Native macOS workaround** - create a Swift helper to request Bluetooth permission before Flutter loads

### 2. Test Sidebar on Different Screen Sizes
- Verify desktop sidebar toggle button works
- Verify mobile swipe gesture works
- Test resizable width on desktop

### 3. Verify "Your Network" Text Not Underlined
- After hot reload, confirm underline is gone

## Other Notes

### Build Commands
```bash
# Clean build with TCC reset
./run.sh macos --clean

# Manual workaround that works:
tccutil reset BluetoothAlways
open build/macos/Build/Products/Debug/bitchat.app
```

### Crash Log Location
`~/Library/Logs/DiagnosticReports/bitchat-*.ips`

### Key File Locations
- BLE package Swift code: `~/.pub-cache/hosted/pub.dev/bluetooth_low_energy_darwin-6.0.0/darwin/Classes/`
- macOS entitlements: `macos/Runner/DebugProfile.entitlements`
- macOS Info.plist: `macos/Runner/Info.plist`

### Bluetooth_low_energy Package Issue
The crash happens at `MyCentralManager.swift:48`:
```swift
init(messenger: FlutterBinaryMessenger) {
    mAPI = MyCentralManagerFlutterAPI(binaryMessenger: messenger)
    mCentralManager = CBCentralManager()  // <-- CRASH HERE
    ...
}
```
This is called during `BluetoothLowEnergyDarwinPlugin.register()` which happens automatically when Flutter loads plugins, before any Dart code runs.
