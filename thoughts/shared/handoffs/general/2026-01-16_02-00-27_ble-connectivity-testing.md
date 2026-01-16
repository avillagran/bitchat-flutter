---
date: 2026-01-16T02:00:27-03:00
session_name: general
researcher: Claude
git_commit: 9db7bfc
branch: main
repository: bitchat-flutter
topic: "BLE Mesh Connectivity Testing and Debugging"
tags: [ble, mesh, android-parity, debugging, bluetooth_low_energy]
status: in_progress
last_updated: 2026-01-16
last_updated_by: Claude
type: implementation_strategy
root_span_id: ""
turn_span_id: ""
---

# Handoff: BLE Connectivity Testing - Chat Messages Not Visible

## Task(s)
1. **[COMPLETED]** Build and test BLE connectivity on Android device
2. **[COMPLETED]** Fix permission issues blocking app startup
3. **[IN PROGRESS]** Debug why chat messages from Android app don't appear in Flutter app

## Critical References
- `plan/04-mesh.md` - BLE mesh architecture and bluetooth_low_energy migration
- `plan/07-android-parity.md` - Android parity status and known issues
- Reference Android app: `/Users/avillagran/Desarrollo/bitchat-android`

## Recent changes
- `android/app/build.gradle:27` - Updated compileSdkVersion 34 → 35
- `android/app/build.gradle:51` - Updated targetSdkVersion 34 → 35
- `android/app/src/main/AndroidManifest.xml:1-13` - Added `tools:remove="android:maxSdkVersion"` to fix location permissions being stripped by plugins

## Learnings

### 1. Plugin Manifest Merging Issue (CRITICAL)
Flutter plugins (`bluetooth_low_energy`, `geolocator`) add `android:maxSdkVersion="30"` to location permissions, which DISABLES them on Android 12+ (SDK 31+).

**Fix:** In AndroidManifest.xml, use:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:remove="android:maxSdkVersion" />
```

### 2. BLE Infrastructure Works
- `bluetooth_low_energy` package correctly implements both Central and Peripheral roles
- GATT Server creates service with UUID `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C`
- Advertising works, devices discover each other
- MTU negotiation works (247 bytes)

### 3. Identity Announcements Work, Chat Messages Don't
- Type 0x01 (ANNOUNCE/Identity) packets: Flutter receives and processes correctly
- Type 0x02 (MESSAGE/Chat) packets: NOT being received or processed
- Logs show `didUpdatePeerList: 1 peers` but NO `didReceiveMessage` calls

### 4. Possible Root Cause
Android may be sending encrypted messages (type 0x11 NOISE_ENCRYPTED) instead of plaintext (0x02 MESSAGE). Need to verify:
- What packet type Android sends for broadcast chat messages
- Whether Noise encryption is being applied automatically

## Post-Mortem

### What Worked
- **bluetooth_low_energy package**: Full GATT server/client working on Android
- **Permission fix via tools:remove**: Overcame plugin manifest merging issues
- **adb permission granting**: `adb shell pm grant` useful for testing without UI flow
- **Targeted logcat filtering**: `grep -E "(flutter.*Gatt|flutter.*Mesh)"` effective for debugging

### What Failed
- **Initial build**: win32 package incompatibility, fixed with `flutter pub upgrade win32`
- **Location permissions**: Stripped by plugins until manifest fix applied
- **Chat message reception**: Still not working - identity works but chat doesn't

### Key Decisions
- Decision: Use `tools:remove` instead of downgrading plugins
  - Alternatives: Pin older plugin versions, use different BLE package
  - Reason: Cleaner fix, maintains latest plugin features

## Artifacts
- `android/app/src/main/AndroidManifest.xml` - Fixed permissions
- `android/app/build.gradle` - SDK version updates
- `lib/features/mesh/ble_manager.dart` - BLE manager (reviewed, works)
- `lib/features/mesh/gatt_server_manager.dart` - GATT server (works)
- `lib/features/mesh/gatt_client_manager.dart` - GATT client (works)
- `lib/features/mesh/bluetooth_mesh_service.dart:477-547` - Packet processing (needs investigation)

## Action Items & Next Steps

### Immediate (Debug Chat Messages)
1. **Verify Android packet types**: Check what type Android uses for broadcast chat
   - Look at `/Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/android/mesh/BluetoothMeshService.kt`
   - Check if `sendPublicMessage()` uses type 0x02 or wraps in Noise

2. **Add debug logging**: In `bluetooth_mesh_service.dart:477` (`_processIncomingPacket`), log ALL packet types received, not just 0x01 and 0x02

3. **Check payload decoding**: `BitchatMessage.fromBinaryPayload()` may be failing silently
   - Add try/catch with detailed error logging

### Fix Bidirectional Discovery (Android no ve Flutter)
4. **Check advertising**: Verify Flutter's advertising is working correctly
   - Check if `GattServerManager.start()` is being called
   - Verify manufacturer data matches Android expectations

5. **Channel matching**: Check if Flutter joins `#mesh` channel by default
   - Android filters messages by channel
   - Flutter may need to join same channel

6. **Private chat UI**: Implement or fix peer selection for DMs

### If Android Uses Noise Encryption
4. **Implement Noise decryption for type 0x11**: The Noise protocol is implemented (`lib/features/crypto/noise_protocol.dart`) but may not be wired for incoming messages

### Testing Commands
```bash
# Install and run
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.bitchat.bitchat/.MainActivity

# Grant permissions
adb shell pm grant com.bitchat.bitchat android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.bitchat.bitchat android.permission.BLUETOOTH_SCAN
adb shell pm grant com.bitchat.bitchat android.permission.BLUETOOTH_CONNECT
adb shell pm grant com.bitchat.bitchat android.permission.BLUETOOTH_ADVERTISE

# Capture BLE logs
adb logcat -v time | grep -E "(flutter.*Gatt|flutter.*Mesh|flutter.*packet)"
```

## User Feedback (Session End)
- **Flutter VE a Android** ✅ (peers aparecen en lista)
- **Android NO VE a Flutter** ❌ (unidireccional)
- **No hay comunicación de mensajes** - posiblemente por canal `#mesh`
- **No puede iniciar chat privado** - UI issue o falta implementación

### Hipótesis adicional
Android está en canal `#mesh`, Flutter probablemente en canal diferente o ninguno. Los mensajes broadcast podrían estar filtrados por canal.

## Other Notes

### Device Used for Testing
- Device ID: `J75T59BAZD45TG85`
- Model: Xiaomi 23090RA98G (zircon)

### UUIDs (Verified Matching Android)
- Service: `F47B5E2D-4A9E-4C5A-9B3F-8E1D2C3A4B5C`
- Characteristic: `A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D`
- CCCD Descriptor: `00002902-0000-1000-8000-00805f9b34fb`

### Message Types (from Android BinaryProtocol.kt)
- 0x01 = ANNOUNCE (identity) ✅ Working
- 0x02 = MESSAGE (chat) ❌ Not receiving
- 0x03 = LEAVE
- 0x10 = NOISE_HANDSHAKE
- 0x11 = NOISE_ENCRYPTED ← Possible actual type for chat?
- 0x20 = FRAGMENT
- 0x21 = REQUEST_SYNC
- 0x22 = FILE_TRANSFER

### Key Log Evidence
```
[GattServerManager] Write request from ..., size: 256 bytes
[BluetoothMeshService] Identity announcement from 813654e4c15d2c8d: anon5938  ← Works
Sent broadcast message: Al fin  ← Flutter sends
[ChatNotifier] didUpdatePeerList: 1 peers  ← Peer detected
# NO didReceiveMessage logs ← Chat not received
```
