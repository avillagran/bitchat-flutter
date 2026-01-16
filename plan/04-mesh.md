- [x] 4.2 Implement GattServerManager and advertising (peripheral mode) with flutter_ble_peripheral (updated: added MTU debug & config)
- [x] 4.3 Implement GattClientManager (scanning, connections, MTU negotiation) - IMPROVED
- [x] 4.4 Debug Settings Panel and Debug Tools Modal (matching Android DebugSettingsSheet)

Changes made (2024-01-16):
- Added `AppConstants.requestMtu` and `AppConstants.requestedMtuSize` to configure MTU requests.
- Modified `GattClientManager` to use the configurable MTU size and to log MTU request outcomes.
- Added debug logging to `GattServerManager` to print advertised service/characteristic UUIDs at startup.

Debug Panel Implementation (2024-01-16):
- Created `lib/features/debug/debug_settings_provider.dart`:
  - DebugSettingsState with toggles: verboseLogging, gattServer, gattClient, packetRelay, requestMtu
  - Sliders: maxConnectionsOverall, maxServerConnections, maxClientConnections, requestedMtuSize
  - Sync settings: seenPacketCapacity, gcsMaxBytes, gcsFprPercent
  - Runtime data: debugMessages, scanResults, connectedDevices, relayStats
  - SharedPreferences persistence for all settings
  - Real-time scan result listener from FlutterBluePlus

- Created `lib/ui/widgets/debug_settings_sheet.dart`:
  - Full-featured debug modal matching Android DebugSettingsSheet
  - Bluetooth Roles section with GATT server/client toggles and connection limits
  - MTU Settings section with toggle and size slider
  - Packet Relay section with incoming/outgoing stats
  - Sync Settings section with GCS filter configuration
  - Connected Devices list with RSSI and connection type
  - Recent Scan Results list
  - Debug Console with scrollable log messages
  - Mesh Service Info display
  - Copy Debug Summary button

- Updated `lib/ui/widgets/about_sheet.dart`:
  - Added "Debug Tools" menu item linking to DebugSettingsSheet
  - Fixed async context warning

- Added `shared_preferences: ^2.2.2` to pubspec.yaml

GattClientManager Improvements (2024-01-16) - Matching Android patterns:
- Refactored to match Android BluetoothGattClientManager connection sequence
- Added proper operation delays (200ms between GATT operations, matching Android)
- Added connection state listener for disconnection handling
- Added retry logic with exponential backoff (max 3 attempts, 5s delay)
- Added protection against concurrent connection attempts to same device
- Added CCCD descriptor detection before enabling notifications
- Added 5s timeout on setNotifyValue with 3 retries
- Continue connection even if notifications fail (for write-only scenarios)
- Added detailed debug logging for each connection step
- Added characteristic property logging (notify, indicate, write, writeNoResponse)
- Added getDebugInfo() method for debugging

Key differences from Android found during analysis:
- Android uses two-step notification: setCharacteristicNotification() + writeDescriptor()
- Flutter Blue Plus combines these in setNotifyValue() which can timeout
- Android requests MTU 517, we use configurable value (default 247 for compatibility)
- Android disconnects on MTU failure, we continue for resilience

Current issues being investigated:
- CCCD write timeouts (GATT_ERROR 133)
- Connection timeout (status 147)
- Service Changed characteristic (0x2a05) CCCD missing

---

## MAJOR MIGRATION: bluetooth_low_energy (2026-01-16)

### Overview
Full migration from `flutter_blue_plus` + `flutter_ble_peripheral` to unified `bluetooth_low_energy` package.

### Why This Migration?
- **flutter_ble_peripheral** only supported advertising, NOT full GATT server with characteristics
- **bluetooth_low_energy** provides complete GATT server + client in one unified package
- Cross-platform: Android, iOS, macOS, Windows (Linux client-only due to bluez limitation)

### Package Changes
```yaml
# Removed:
flutter_blue_plus: ^1.34.0
flutter_ble_peripheral: ^1.1.0

# Added:
bluetooth_low_energy: ^6.0.2
```

### Files Created
| File | Description |
|------|-------------|
| `lib/features/mesh/ble_manager.dart` | Singleton BLE manager with Central + Peripheral wrappers |

### Files Modified
| File | Changes |
|------|---------|
| `lib/features/mesh/gatt_server_manager.dart` | Complete rewrite with PeripheralManager, full GATT service |
| `lib/features/mesh/gatt_client_manager.dart` | Migrated to CentralManager API |
| `lib/features/mesh/bluetooth_mesh_service.dart` | Updated to Peripheral type, implements GattServerDelegate |
| `lib/features/debug/debug_settings_provider.dart` | Updated scan result handling for new API |
| `pubspec.yaml` | Package swap |

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    BluetoothMeshService                      │
│        implements BluetoothConnectionManagerDelegate         │
│        implements GattServerDelegate                         │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│    GattServerManager     │     │    GattClientManager    │
│   (PeripheralManager)    │     │    (CentralManager)     │
│  - Full GATT service     │     │  - Scanning             │
│  - Read/Write/Notify     │     │  - Connections          │
│  - Advertising           │     │  - Notifications        │
└─────────────────────────┘     └─────────────────────────┘
                              │
                              ▼
              ┌─────────────────────────────┐
              │         BleManager          │
              │   (Singleton Abstraction)   │
              │  - Platform detection       │
              │  - State management         │
              └─────────────────────────────┘
```

### Platform Support Matrix

| Platform | Central (Scan/Connect) | Peripheral (GATT Server) |
|----------|------------------------|--------------------------|
| Android  | ✅ | ✅ |
| iOS      | ✅ | ✅ (ad limits) |
| macOS    | ✅ | ✅ |
| Windows  | ✅ | ✅ (ad limits) |
| Linux    | ✅ | ❌ (bluez limitation) |

### Key Type Mappings

| Old (flutter_blue_plus) | New (bluetooth_low_energy) |
|-------------------------|---------------------------|
| `BluetoothDevice` | `Peripheral` |
| `device.remoteId` | `peripheral.uuid` |
| `ScanResult` | `DiscoveredEventArgs` |
| `BluetoothAdapterState` | `BluetoothLowEnergyState` |
| `Guid` | `UUID` |

### GATT Server Capabilities (NEW!)

The new GattServerManager now supports:
- ✅ Custom GATT service creation
- ✅ Read requests (responds with cached value)
- ✅ Write requests (notifies delegate with received data)
- ✅ Notifications to subscribed centrals
- ✅ Tracking of connected/subscribed centrals
- ✅ sendData() to specific or all centrals

### Next Steps
- [ ] Test on Android device with Android reference app
- [ ] Verify bidirectional mesh communication
- [ ] Add mesh topology visualization (ForceDirectedMeshGraph)
- [ ] Fix any remaining test files that reference old flutter_blue_plus types
