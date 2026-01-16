---
date: 2026-01-16T03:24:10-03:00
session_name: general
researcher: claude
git_commit: 9db7bfc
branch: main
repository: bitchat-flutter
topic: "BLE CCCD Subscription Debug - Flutter→Android Communication"
tags: [bluetooth, mesh, gatt, cccd, notifications, android, flutter]
status: partial_minus
outcome: PARTIAL_MINUS
outcome_notes: "Android→Flutter works. Flutter→Android still fails despite multiple fixes."
last_updated: 2026-01-16
last_updated_by: claude
type: debugging_session
root_span_id: ""
turn_span_id: ""
---

# Handoff: BLE CCCD Subscription - Flutter→Android Still Failing

## Task(s)

1. **Fix Flutter→Android BLE communication** - IN PROGRESS (BLOCKED)
   - Android→Flutter works (via GATT server write requests)
   - Flutter→Android fails (notifications not received by Android)
   - Root cause identified: Android not subscribing to CCCD notifications

## Critical References

- `lib/features/mesh/gatt_server_manager.dart` - Flutter's GATT server with CCCD
- `lib/features/mesh/bluetooth_mesh_service.dart` - Main mesh service with routing logic
- `/Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/mesh/BluetoothGattClientManager.kt:462-473` - Android CCCD subscription code

## Recent changes

- `lib/features/mesh/gatt_server_manager.dart:250-302` - Added `sendToSpecificCentral()` method
- `lib/features/mesh/gatt_server_manager.dart:298-302` - Added `isCentralConnected()` method
- `lib/features/mesh/gatt_server_manager.dart:353-361` - Added CCCD descriptor to characteristic
- `lib/features/mesh/bluetooth_mesh_service.dart:324-394` - Rewrote `broadcastPacket()` with proper routing
- `lib/features/mesh/bluetooth_mesh_service.dart:379-394` - Added GATT client fallback write
- `lib/features/mesh/gatt_client_manager.dart:281-296` - Added service discovery retry (3 attempts)

## Learnings

### ROOT CAUSE CONFIRMED: CCCD Subscription Not Working

The BLE notification flow requires:
1. Central (Android) connects to Peripheral (Flutter's GATT server)
2. Central writes `ENABLE_NOTIFICATION_VALUE` to CCCD descriptor (UUID: `00002902-*`)
3. Peripheral receives this and adds central to `_subscribedCentrals`
4. Peripheral can then send notifications to subscribed centrals

**The problem**: `_subscribedCentrals` is always 0, meaning:
- Either Flutter's `bluetooth_low_energy` package doesn't fire `characteristicNotifyStateChanged` event
- Or Android's CCCD write is failing silently

### Android BLE Architecture (from code analysis)

**Android receives data via TWO mechanisms:**
1. **As GATT Server**: `onCharacteristicWriteRequest()` - Flutter writes to Android
2. **As GATT Client**: `onCharacteristicChanged()` - Flutter notifies Android (REQUIRES CCCD subscription)

Android DOES subscribe to CCCD at `BluetoothGattClientManager.kt:463-467`:
```kotlin
gatt.setCharacteristicNotification(characteristic, true)
descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
gatt.writeDescriptor(descriptor)
```

### Device UUID Mapping Issue

Two different UUIDs for the same Android device:
- Central connected to Flutter's server: `76f45ae5262b`
- Peripheral Flutter connected to: `79d08bd3221f`

This complicates peer-to-device routing.

### Service Discovery Failing

Flutter's GATT client finds 0 services when connecting to Android:
```
[GattClientManager] Found 0 services on 00000000-0000-0000-0000-79d08bd3221f
```

Added retry mechanism (3 attempts with 500ms delay) but still fails.

## Post-Mortem

### What Worked
- Routing logic improvement: `broadcastPacket()` now correctly identifies peers connected as centrals
- `sendToSpecificCentral()` successfully sends notifications to connected centrals
- GATT server receives Android writes correctly (Android→Flutter path)
- Font size fix (15sp→13sp) applied successfully

### What Failed
- Tried: Adding CCCD descriptor explicitly → Still 0 subscribed centrals
- Tried: Service discovery retry → Still finds 0 services
- Tried: GATT client fallback write → Fails with "No cached characteristic"
- Error: `IllegalStateException` when Flutter tries to enable notifications on Android's characteristic

### Key Decisions
- Decision: Keep both notification AND write fallback paths
  - Reason: Different Android devices may behave differently
- Decision: Added CCCD descriptor to characteristic
  - Reason: Required for CCCD-based notification subscription

## Artifacts

- `lib/features/mesh/gatt_server_manager.dart:250-361` - New methods and CCCD
- `lib/features/mesh/bluetooth_mesh_service.dart:324-394` - Rewritten broadcastPacket
- `lib/features/mesh/gatt_client_manager.dart:281-296` - Service discovery retry

## Action Items & Next Steps

### PRIORITY 1: Debug CCCD Subscription

1. **Check if `characteristicNotifyStateChanged` event fires**
   - Add debug logging in `_handleNotifyStateChanged()` at `gatt_server_manager.dart:487`
   - May need to check `bluetooth_low_energy` package source for CCCD handling

2. **Verify Android's CCCD write succeeds**
   - Check Android logcat for CCCD write success/failure
   - Verify descriptor UUID matches: `00002902-0000-1000-8000-00805f9b34fb`

3. **Alternative: Different BLE Package**
   - Consider `flutter_blue_plus` which may handle CCCD differently
   - Would require significant refactoring

### PRIORITY 2: Service Discovery Fix

1. **Why does Flutter find 0 services on Android?**
   - Android's GATT server IS running (it receives Flutter writes)
   - Service discovery timing issue?
   - Try longer delays or different discovery approach

### PRIORITY 3: Alternative Communication Path

If notifications continue to fail:
1. Have Android poll/read Flutter's characteristic value
2. Or implement a custom acknowledgment protocol over writes

## Other Notes

### App Running
Background shell `b9237e5` running:
```bash
fvm flutter run -d 23090RA98G
```

### Key UUIDs
- Service: `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C`
- Characteristic: `A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D`
- CCCD: `00002902-0000-1000-8000-00805f9b34fb`

### Log Patterns to Watch
- `subscribed centrals: X` - Should be >0 when Android subscribes
- `Notify state changed` - Should appear when Android writes CCCD
- `Found X services` - Service discovery success

### Previous Handoff
`thoughts/shared/handoffs/general/2026-01-16_02-54-01_ble-mesh-flutter-android-debug.md`
