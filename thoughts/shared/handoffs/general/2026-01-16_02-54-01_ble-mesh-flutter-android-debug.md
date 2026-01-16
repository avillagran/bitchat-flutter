---
date: 2026-01-16T02:54:01-03:00
session_name: general
researcher: claude
git_commit: 9db7bfc
branch: main
repository: bitchat-flutter
topic: "BLE Mesh Flutter-Android Communication Debug"
tags: [bluetooth, mesh, gatt, android, flutter, debugging]
status: partial_minus
outcome: PARTIAL_MINUS
outcome_notes: "Android→Flutter FUNCIONA. Flutter→Android aún no. Font size reducido a 13sp."
last_updated: 2026-01-16
last_updated_by: claude
type: debugging_session
root_span_id: ""
turn_span_id: ""
---

# Handoff: BLE Mesh Flutter→Android Message Debugging

## Task(s)

1. **UI Badges Implementation** - COMPLETED
   - Added status badges to header (LocationBadge, TorStatusDot, PoWStatusBadge)
   - Created `lib/ui/widgets/status_badges.dart`
   - Modified `lib/ui/chat_screen.dart` to include badges

2. **AboutSheet Android Parity** - COMPLETED
   - Rewrote `lib/ui/widgets/about_sheet.dart` to match Android design
   - Added Features section, Theme selector, Settings toggles (Background, PoW, Tor)
   - Added PoW difficulty slider and Emergency Wipe warning

3. **BLE Mesh Communication Debug** - IN PROGRESS (ROOT CAUSE FOUND)
   - Diagnosed why Flutter messages don't reach Android app
   - **ROOT CAUSE IDENTIFIED** - see Learnings section

## Critical References

- `lib/features/mesh/bluetooth_mesh_service.dart` - Main mesh service with `sendMessage()` bug
- `plan/07-android-parity.md` - Full parity plan with GATT server issues documented
- `/Users/avillagran/Desarrollo/bitchat-android/` - Reference Android implementation

## Recent changes

- `lib/ui/widgets/about_sheet.dart` - Nostr Account section, Tor status display added
- `lib/ui/widgets/status_badges.dart` - StatusBadgesRow, LocationBadge, TorStatusDot, PoWStatusBadge
- `lib/ui/chat_screen.dart` - Individual badges in header, _buildPeerCounter
- `lib/features/chat/chat_provider.dart` - Added currentGeohash to ChatState
- `lib/features/mesh/bluetooth_mesh_service.dart:284-297` - **FIX: Sends encoded packet (63 bytes) instead of plain UTF-8 (4 bytes)**
- `lib/features/mesh/bluetooth_mesh_service.dart:590-613` - Added packet type handlers (0x03, 0x04, 0x21)
- `lib/ui/theme/bitchat_typography.dart:10` - **FIX: baseFontSize 15→13sp**

## Learnings

### ROOT CAUSE: Message Format Mismatch

The Flutter app sends messages in **TWO formats** in `bluetooth_mesh_service.dart:239-291`:

1. **Structured packet** via `broadcastPacket()` - 61 bytes, correctly encoded
2. **Plain UTF-8** via `sendDataToAllConnected()` - ONLY the raw text bytes (e.g., "Hola" = 4 bytes)

**The bug is at lines 284-290:**
```dart
if (_gattServerManager.connectedCount > 0) {
  final plainText = utf8.encode(content);  // ← WRONG! Just "Hola" = 4 bytes
  await _gattServerManager.sendDataToAllConnected(Uint8List.fromList(plainText));
}
```

This sends raw UTF-8 text without any packet structure. Android expects the full `BitchatPacket` format.

### Log Evidence

From debug session:
```
I/flutter: [GattServerManager] Sent 61 bytes to ... via notification  (correct!)
I/flutter: [GattServerManager] Sent 4 bytes to ... (connected)        (WRONG!)
```

The 61-byte notification is correct, but the 4-byte "connected" write is just "Hola" without structure.

### Connection Flow Working

- Identity announcements (type 0x1) are received correctly
- Peer `813654e4c15d2c8d` (nickname: `cquiroz`) detected from Android
- GATT server/client connections established
- Notifications work (61 bytes sent correctly)

### The Real Problem

Android connects but may not **subscribe** to notifications. When Flutter sends:
1. **Notifications** → Only go to subscribed centrals (works)
2. **Direct writes** → Go to all connected centrals but send wrong format

## Post-Mortem

### What Worked
- BLE initialization and scanning work correctly
- GATT server advertising with correct service UUID
- Identity announcement parsing (type 0x1 packets)
- Notification-based packet delivery to subscribed peers
- Message persistence with Hive (loaded 16 messages on startup)

### What Failed
- Tried: Sending plain UTF-8 for "Android compatibility" → Failed because Android expects structured packets
- Error: "no device found for peer" in broadcastPacket → The peer-to-device UUID mapping is incomplete
- Issue: `sendDataToAllConnected` sends raw text instead of encoded packet

### Key Decisions
- Decision: Keep both notification and direct-write paths
  - Alternatives: Only use notifications, or only use direct writes
  - Reason: Different Android devices may or may not subscribe to notifications

## Artifacts

- `lib/ui/widgets/about_sheet.dart` - Rewritten AboutSheet
- `lib/ui/widgets/status_badges.dart` - NEW status badges
- `lib/features/mesh/bluetooth_mesh_service.dart:284-290` - BUG LOCATION
- `plan/07-android-parity.md` - Updated with session notes
- `/tmp/claude/-Users-avillagran-Desarrollo-bitchat-flutter/tasks/b03b816.output` - Debug logs

## Action Items & Next Steps

### Status Update
- [x] Header actualizado con badges individuales (Location, Tor, PoW, PeerCounter)
- [x] AboutSheet con Nostr Account y Tor status
- [x] Font size reducido a 13sp
- [x] Fix aplicado: sendMessage envía paquete codificado (63 bytes)
- [ ] **PENDIENTE: Flutter→Android aún no funciona** (Android→Flutter SÍ funciona)

### Debug Next Steps (PRIORITY 1)

1. **Verificar que Android recibe el paquete de 63 bytes**
   - Revisar logs de Android BluetoothMeshService
   - Verificar que parsePacket/decode maneja el formato correctamente

2. **Posible problema: Android no subscribe a notifications**
   - Flutter envía via `sendDataToAllConnected` (direct write)
   - Android puede no estar escuchando writes, solo notifications
   - Revisar `GattServerManager.sendDataToAllConnected` - usa notifyCharacteristic

### Future Tasks (from plan/07-android-parity.md)

- [ ] 7.2-7.3 GATT Server with characteristics (platform channels if flutter_ble_peripheral insufficient)
- [ ] 7.10-7.14 UI Sheets: LocationChannels, PrivateChat, Verification, DebugSettings

## Other Notes

### Debug App Running
The app is currently running in background shell `b03b816`:
```bash
fvm flutter run -d 23090RA98G
```
DevTools available at: http://127.0.0.1:9100

### Device Info
- Android device: 23090RA98G (Android 15, API 35)
- Flutter: 3.19.5 (via fvm)
- Build: `flutter build apk --debug` works

### Android Reference
The Android implementation is at `/Users/avillagran/Desarrollo/bitchat-android/`
Key files:
- `app/src/main/java/com/bitchat/android/mesh/BluetoothMeshService.kt`
- `app/src/main/java/com/bitchat/android/ui/ChatHeader.kt` (badge reference)

### Commands to Resume
```bash
# Kill running app
fvm flutter run -d 23090RA98G  # or use DevTools

# After fix, rebuild and test
fvm flutter run -d 23090RA98G 2>&1 | grep -E "flutter|GATT|mesh|Message"
```
