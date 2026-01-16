---
date: 2026-01-16T08:39:32Z
session_name: general
researcher: Claude
git_commit: 9848e3a
branch: main
repository: bitchat-flutter
topic: "Flutter-Android BLE Mesh Signature & Message Payload Compatibility"
tags: [ble-mesh, signature-verification, android-compatibility, pkcs7-padding]
status: partial
last_updated: 2026-01-16
last_updated_by: Claude
type: implementation_strategy
root_span_id:
turn_span_id:
---

# Handoff: Flutter-Android Signature Verification & Message Payload Fix

## Task(s)

### 1. Signature Verification Fix - COMPLETED ✅
**Problem:** Flutter packets had valid Ed25519 signatures but Android rejected them.

**Root Cause Found:** Padding mismatch in `encodeForSigning()`:
- Android: `BinaryProtocol.encode()` applies PKCS#7 padding (to block sizes 256/512/1024/2048)
- Flutter: Was returning raw unpadded bytes

**Fix Applied:** Modified `lib/protocol/packet_codec.dart:140-143` to apply same PKCS#7 padding.

**Result:** Android now successfully verifies Flutter signatures:
```
✅ Ed25519 signature verification: true
✅ Verified announce from 997b76157eaf2e88
```

### 2. Message Payload Format Fix - COMPLETED ✅
**Problem:** Messages from Flutter appeared "partially encrypted" in Android.

**Root Cause Found:** Payload encoding mismatch:
- Android expects: Plain UTF-8 bytes (`content.toByteArray(Charsets.UTF_8)`)
- Flutter was sending: Structured binary format (flags + timestamp + lengths + data)

**Fix Applied:** Modified `lib/features/mesh/bluetooth_mesh_service.dart:274-276` to send plain UTF-8.

### 3. Message Delivery - IN PROGRESS ⚠️
**Current Issue:** Android receives ANNOUNCE (type 1) from Flutter but NOT MESSAGE (type 2).

**Observed:**
- Flutter logs show messages being signed and sent ("Ggg", "Gghh")
- Android only logs receiving type 1 from Flutter peer 997b76157eaf2e88
- Type 2 packets never appear in Android reception logs

**Suspected Cause:** BLE routing issue - Flutter may be sending via GATT server to centrals, but Android connection role mismatch.

## Critical References
- `lib/protocol/packet_codec.dart` - Packet encoding/signing
- `lib/features/mesh/bluetooth_mesh_service.dart` - Message sending and BLE routing
- `/Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/mesh/MessageHandler.kt:382-440` - Android message processing

## Recent changes

1. `lib/protocol/packet_codec.dart:140-143` - Added PKCS#7 padding to `encodeForSigning()`:
```dart
final optimalSize = MessagePadding.optimalBlockSize(raw.length);
return MessagePadding.pad(raw, optimalSize);
```

2. `lib/features/mesh/bluetooth_mesh_service.dart:274-276` - Changed to plain UTF-8 payload:
```dart
// Use plain UTF-8 payload for Android compatibility
final binary = Uint8List.fromList(utf8.encode(content));
```

## Learnings

### Signature Verification
- Android's `toBinaryDataForSigning()` calls `BinaryProtocol.encode()` which applies PKCS#7 padding
- Signing bytes MUST be identical on both platforms - any byte difference = signature failure
- Flutter was signing 108 raw bytes, Android was verifying against 256 padded bytes

### Message Payload Format
- Android `MessageHandler.handleBroadcastMessage()` line 432: `String(packet.payload, Charsets.UTF_8)`
- Android expects plain text, not structured binary
- Flutter's `BitchatMessage.toBinaryPayload()` format is for Flutter-to-Flutter only

### BLE Connection Roles
- Flutter connects to Android as GATT client (reads from Android's GATT server)
- Android connects to Flutter as GATT client (reads from Flutter's GATT server)
- Messages sent via wrong role (e.g., server-only when peer is client) won't arrive

## Post-Mortem

### What Worked
- **Debug agent analysis:** Quickly identified padding mismatch by comparing byte-by-byte encoding
- **Parallel log monitoring:** adb logcat on both devices revealed exactly where packets were/weren't arriving
- **Code comparison approach:** Reading both codebases side-by-side revealed format differences

### What Failed
- Tried: Initially modified Android code → User clarified Flutter should match Android (Android is reference)
- Error: First message test showed "NO_SIGNING_KEY_AVAILABLE" → Had to wait for ANNOUNCE to arrive first
- BLE reconnection issues: Devices disconnected during testing, required app restarts

### Key Decisions
- Decision: Apply padding in Flutter rather than remove it from Android
  - Alternatives: Could have added `encodeRaw()` to Android
  - Reason: Android is the reference implementation; Flutter should match it

- Decision: Use plain UTF-8 for message payload
  - Alternatives: Could have added structured format parsing to Android
  - Reason: Simpler, matches existing Android behavior, no Android changes needed

## Artifacts
- `lib/protocol/packet_codec.dart:112-144` - `encodeForSigning()` with padding fix
- `lib/features/mesh/bluetooth_mesh_service.dart:262-307` - `sendMessage()` with UTF-8 payload
- `plan/handoffs/2026-01-16_signature-verification-debug.md` - Previous session handoff
- `.claude/cache/agents/debug-agent/latest-output.md` - Detailed byte comparison analysis

## Action Items & Next Steps

### Priority 1: BLE Message Delivery
1. **Debug MESSAGE (type 2) delivery:**
   - Check Flutter's `broadcastPacket()` routing logic (~lines 312-400)
   - Verify which BLE role Flutter uses to send to Android peer
   - Add logging to confirm packet is written to correct characteristic

2. **Verify GATT connection roles:**
   - Check if Flutter sends type 1 and type 2 via same path
   - Android receives type 1 but not type 2 - why the difference?

### Priority 2: UI/UX Parity with Android
3. **Username display in chat:**
   - Username saves correctly in user panel
   - But chat messages show peer ID instead of username
   - Need to resolve nickname from peer ID when displaying messages

4. **Visual styling to match Android:**
   - User colors don't match Android's color scheme
   - Message colors don't match
   - Typography size differs from Android
   - Compare Android's `ChatScreen.kt` / `MessageComponents.kt` styling

5. **Slash commands (/):**
   - Android shows command list/help when typing `/` in input
   - Flutter needs similar slash command popup
   - Check Android's input handling for command detection

6. **User mentions (@):**
   - Android shows available users list when typing `@`
   - Flutter needs mention autocomplete popup
   - Check Android's mention detection and user list display

### Testing & Commit
7. **Test commands:**
   ```bash
   # Monitor Flutter
   adb -s J75T59BAZD45TG85 logcat | grep -iE "flutter.*type 2|sendMessage|broadcastPacket"

   # Monitor Android
   adb -s 192.168.1.34:45421 logcat | grep -iE "997b76|type 2|Parsed packet"
   ```

8. **Once messages work, commit changes:**
   - Signature fix (packet_codec.dart)
   - Payload fix (bluetooth_mesh_service.dart)

## Other Notes

### Device Info
- Flutter device: J75T59BAZD45TG85 (USB)
- Android device: 192.168.1.34:45421 (WiFi debug) - port changes on reconnect
- Flutter peer ID: 997b76157eaf2e88
- Android peer ID: 813654e4c15d2c8d (nickname: cquiroz)

### Android Message Processing Path
1. `BluetoothGattClientManager` receives packet
2. `PacketProcessor.processPacket()` validates signature
3. `MessageHandler.handleMessage()` routes by type
4. `handleBroadcastMessage()` decodes UTF-8 payload

### Key Files for BLE Routing Investigation
- `lib/features/mesh/bluetooth_mesh_service.dart:312-400` - `broadcastPacket()`
- `lib/features/mesh/gatt_client_manager.dart` - GATT client writes
- `lib/features/mesh/gatt_server_manager.dart` - GATT server notifications
