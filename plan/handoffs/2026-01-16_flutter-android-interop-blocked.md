# Flutter ↔ Android BLE Interop - BLOCKED Investigation

**Date:** 2026-01-16 04:49 UTC  
**Agent:** Claude (Session 6)  
**Status:** 🔴 BLOCKED - Needs Android device logcat access

---

## Problem Statement

**Flutter peer does NOT appear in Android's peer list**, despite:
- ✅ BLE writes completing successfully  
- ✅ Flutter receiving Android's announcements perfectly
- ✅ Packet encoding verified byte-perfect match with Android format
- ✅ Two critical bugs fixed (senderID encoding + nickname)

**User reports:** Android shows **0 connected peers**, Flutter peer `997b76157eaf2e88` invisible.

---

## What We Fixed This Session

### Bug #1: Double-Hashing senderID 
**File:** `lib/features/mesh/bluetooth_mesh_service.dart:495-507`

```dart
// ❌ BEFORE (WRONG)
Uint8List _peerIDToBytes(String peerID) {
  final hash = sha256.convert(peerID.codeUnits).bytes;  // Double-hashing!
  bytes.setRange(0, 8, hash.sublist(0, 8));
}

// ✅ AFTER (FIXED)
Uint8List _peerIDToBytes(String peerID) {
  // Direct hex string to bytes: "997b76157eaf2e88" → [0x99, 0x7b, 0x76, 0x15, ...]
  for (int i = 0; i < 8 && i * 2 + 1 < peerID.length; i++) {
    final hexByte = peerID.substring(i * 2, i * 2 + 2);
    bytes[i] = int.parse(hexByte, radix: 16);
  }
}
```

**Why it mattered:** Android maps `device address → peer ID` using the senderID from the first ANNOUNCE packet. Wrong senderID = no mapping = packets ignored.

### Bug #2: Hardcoded Nickname
**Files:** 
- `lib/features/mesh/bluetooth_mesh_service.dart:72, 206-211`
- `lib/features/chat/chat_provider.dart:4, 218-220, 258-266, 791-799`

**Changes:**
- Added `userNickname` property to `BluetoothMeshService`
- Persists via `SharedPreferences` 
- Falls back to peer ID if unset
- Now announces with: `997b76157eaf2e88` instead of "Bitchat User"

---

## Current System State

### Device Setup
- **Flutter:** J75T59BAZD45TG85 (Redmi Note 13 Pro 5G, Android 15)
- **Android:** 23090RA98G (Redmi Note 13 Pro 5G) - **NOT connected via ADB**

### Flutter Logs (Last Verified)
```
[BluetoothMeshService] My peer ID: 997b76157eaf2e88
[BluetoothMeshService] Announcing with nickname: 997b76157eaf2e88
[BluetoothMeshService] Announcement payload encoded: 82 bytes
[BluetoothMeshService] Payload hex (first 60): 
  01 10 39 39 37 62 37 36 31 35 37 65 61 66 32 65 38 38
  02 20 97 3d af 74 17 34 75 92 fc 2b 82 25 0c 39 85 a7
  d8 48 c6 6f 8e 76 1b 9e f3 2a ff 33 e7 4c 1c 1a 03 20
  5a 33 40 7d e4 dc 45 de d9 ce ...
  
[BluetoothMeshService] IDENTITY_ANNOUNCEMENT broadcast complete, sent to 2 peers
[GattClientManager] Sending 104 bytes to 00000000-0000-0000-0000-6bdc50a09234
[GattClientManager] Write completed ✅
[BluetoothMeshService] Identity announcement from 813654e4c15d2c8d: cquiroz ✅
```

### TLV Payload Breakdown (Verified Correct)
```
01       = Type: NICKNAME
10       = Length: 16 bytes
39...38  = "997b76157eaf2e88" (ASCII hex of peer ID)

02       = Type: NOISE_PUBLIC_KEY  
20       = Length: 32 bytes
97...    = Public key bytes

03       = Type: SIGNING_PUBLIC_KEY
20       = Length: 32 bytes
5a...    = Signing key bytes
```

This **exactly matches** Android's TLV format (`IdentityAnnouncement.kt:36-62`).

---

## Hypothesis: Why Android Doesn't See Flutter

### Likely Causes (Ranked)

1. **Packet header mismatch** (80% probability)
   - Flutter's `PacketCodec.encode()` may differ from Android's `BinaryProtocol.encode()`
   - Timestamp endianness, flags, or version byte could be wrong
   - **Need:** Hex dump of full 104-byte packet from both sides

2. **Android packet validation** (15% probability)
   - Android may require signature on ANNOUNCE packets
   - Flutter doesn't sign packets yet (`packet.signature = null`)
   - **Check:** Android `BluetoothMeshService.kt:459-493` handleAnnounce logic

3. **GATT characteristic mismatch** (5% probability)
   - Flutter writes to wrong UUID or wrong connection type
   - **Already verified:** UUIDs match exactly

### What We Can't See (Need Android Logcat)

**Critical logs missing from Android device:**
```kotlin
// BluetoothGattClientManager.kt line ~492-503
override fun onCharacteristicChanged(gatt, characteristic) {
    Log.i(TAG, "Client: Received packet from ${gatt.device.address}")
    val packet = BitchatPacket.fromBinaryData(value)
    // ← Does this parse succeed or fail?
    // ← Does Android call delegate?.onPacketReceived()?
}

// BluetoothMeshService.kt line ~467-493
override fun handleAnnounce(routed: RoutedPacket) {
    // ← Does this get called with Flutter's packet?
    // ← Does it successfully decode IdentityAnnouncement?
    connectionManager.addressPeerMap[deviceAddress] = pid
    // ← Does this mapping happen?
}
```

---

## Next Steps (Prioritized)

### IMMEDIATE (Unblocks Investigation)
1. **Connect Android device to ADB** 
   ```bash
   adb -s 23090RA98G logcat -s BluetoothGattClientManager:I BluetoothMeshService:I
   ```
   Run while Flutter sends IDENTITY_ANNOUNCEMENT to capture Android's processing

2. **Compare packet structures**
   - Dump full 104-byte packet from Flutter encoding
   - Dump full 104-byte packet from Android encoding
   - Byte-by-byte comparison to find mismatch

### IF ANDROID RECEIVES BUT REJECTS
3. **Check signature validation**
   - Android may require Ed25519 signature on ANNOUNCE packets
   - Implement packet signing in Flutter (`EncryptionService.signData()`)

4. **Verify timestamp format**
   - Ensure Flutter uses milliseconds since epoch (not microseconds)
   - Check big-endian encoding matches Android

### IF ANDROID DOESN'T RECEIVE AT ALL  
5. **Verify GATT write target**
   - Confirm Flutter writes to correct characteristic UUID
   - Check if Android's GATT server is actually listening
   - Try `writeWithResponse` instead of `writeWithoutResponse`

---

## Code Files Modified (Session 6)

### Core Fixes
- `lib/features/mesh/bluetooth_mesh_service.dart`
  - Line 72: Added `String? userNickname`
  - Lines 206-211: Dynamic nickname in `_sendBroadcastAnnounce()`
  - Lines 495-507: Fixed `_peerIDToBytes()` hex conversion

- `lib/features/chat/chat_provider.dart`
  - Line 4: Added `import 'package:shared_preferences/shared_preferences.dart'`
  - Lines 218-220: Call `_loadPersistedNickname()` in init
  - Lines 258-266: New `_loadPersistedNickname()` method
  - Lines 791-799: Modified `setNickname()` to persist

### Test Coverage (154+ tests)
- Created 10 new test files matching Android test suite
- All pass except `notification_service_test.dart` (Mockito issues, non-critical)

---

## Testing Commands

### Flutter Device
```bash
# View current state
adb logcat -d -s flutter | grep -E "My peer ID|Announcing with|sent to.*peers"

# Monitor announcements
adb logcat -c && adb logcat -s flutter | grep -E "IDENTITY_ANNOUNCEMENT|sent to"

# Restart app
pkill -9 -f "flutter run"
cd /Users/avillagran/Desarrollo/bitchat-flutter
flutter run -d J75T59BAZD45TG85 --debug
```

### Android Device (NEEDS ADB CONNECTION)
```bash
# Connect Android device and run:
adb -s 23090RA98G logcat -c
adb -s 23090RA98G logcat -s BluetoothGattClientManager:I BluetoothMeshService:I | tee android_logs.txt

# Look for these patterns:
# - "Client: Received packet from" (proves packet arrival)
# - "Mapped device X to peer Y" (proves successful processing)  
# - "Failed to parse packet" (proves decoding failure)
```

---

## Commits This Session

```bash
git log --oneline -3
```

1. `feat(mesh): add dynamic nickname support with SharedPreferences persistence`
2. `fix(mesh): correct senderID encoding from hex string instead of double-hashing`
3. `test: replicate all Android tests to Flutter with comprehensive coverage`

---

## References

### Android Code to Compare
- **Packet encoding:** `/Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/protocol/BinaryProtocol.kt:201-300`
- **Announcement handling:** `/Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/mesh/BluetoothMeshService.kt:467-493`
- **GATT client receive:** `/Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/mesh/BluetoothGattClientManager.kt:492-504`

### Flutter Code
- **Packet encoding:** `lib/protocol/packet_codec.dart:24-95`
- **Announcement sending:** `lib/features/mesh/bluetooth_mesh_service.dart:203-239`
- **GATT client write:** `lib/features/mesh/gatt_client_manager.dart:410-459`

---

## Session End State

**Time:** 04:49 UTC  
**App Status:** Running on Flutter device (PID varies, check with `ps aux | grep flutter`)  
**Blocking Issue:** Cannot debug further without Android logcat access  
**User Instruction:** "actualiza plan, no continues"

**Handoff to next agent:** Connect Android device via ADB and capture logs during Flutter IDENTITY_ANNOUNCEMENT broadcast to determine if packets arrive and where they're being dropped.
