# Flutter ↔ Android Interoperability

**Date:** 2026-01-16 08:45 UTC
**Agent:** Claude (Session 8)
**Status:** 🟡 IN PROGRESS

---

## Completed ✅

### 1. Signature Verification - FIXED
**Root Cause:** PKCS#7 padding mismatch
- Android `BinaryProtocol.encode()` applies padding to block sizes [256, 512, 1024, 2048]
- Flutter was signing raw unpadded bytes

**Fix:** `lib/protocol/packet_codec.dart:140-143`
```dart
final optimalSize = MessagePadding.optimalBlockSize(raw.length);
return MessagePadding.pad(raw, optimalSize);
```

**Result:** `✅ Ed25519 signature verification: true`

### 2. Message Payload Format - FIXED
**Root Cause:** Format mismatch
- Android expects: Plain UTF-8 (`content.toByteArray(Charsets.UTF_8)`)
- Flutter was sending: Structured binary (flags + timestamp + lengths + data)

**Fix:** `lib/features/mesh/bluetooth_mesh_service.dart:274-276`
```dart
final binary = Uint8List.fromList(utf8.encode(content));
```

---

## In Progress 🟡

### 3. Message Delivery (Type 2)
**Issue:** Android receives ANNOUNCE (type 1) but NOT MESSAGE (type 2) from Flutter.

**Observed:**
- Flutter logs: Messages signed and sent ("Ggg", "Gghh")
- Android logs: Only type 1 from 997b76157eaf2e88, no type 2

**Suspected:** BLE routing issue - check `broadcastPacket()` GATT roles

---

## Pending Tasks 📋

### 4. Username Display in Chat
- Username saves correctly in user panel
- Chat messages show peer ID instead of nickname
- Need to resolve nickname from peer ID when displaying

### 5. Visual Styling (Match Android)
- User colors don't match Android
- Message colors don't match
- Typography size differs
- Reference: Android's `ChatScreen.kt`, `MessageComponents.kt`

### 6. Slash Commands (/)
- Android shows command list when typing `/`
- Flutter needs command popup
- Check Android's input handling

### 7. User Mentions (@)
- Android shows user list when typing `@`
- Flutter needs mention autocomplete
- Check Android's mention detection

---

## Files Modified

| File | Change |
|------|--------|
| `lib/protocol/packet_codec.dart:140-143` | Added PKCS#7 padding to `encodeForSigning()` |
| `lib/features/mesh/bluetooth_mesh_service.dart:274-276` | Plain UTF-8 payload |

---

## Device Info

- Flutter: J75T59BAZD45TG85 (USB)
- Android: 192.168.1.34:45421 (WiFi - port changes)
- Flutter peer: 997b76157eaf2e88
- Android peer: 813654e4c15d2c8d (cquiroz)

---

## Test Commands

```bash
# Flutter logs
adb -s J75T59BAZD45TG85 logcat | grep -iE "flutter.*type 2|sendMessage"

# Android logs
adb -s 192.168.1.34:45421 logcat | grep -iE "997b76|type 2|Parsed packet"

# Reconnect Android
adb connect 192.168.1.34:<check-new-port>
```

---

## Reference: Android Code Locations

| Feature | File |
|---------|------|
| Message processing | `MessageHandler.kt:382-440` |
| Message sending | `BluetoothMeshService.kt:694-715` |
| Chat UI | `ChatScreen.kt`, `MessageComponents.kt` |
| Input handling | `InputComponents.kt` |
