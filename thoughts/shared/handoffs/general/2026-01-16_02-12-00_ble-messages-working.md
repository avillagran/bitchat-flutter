---
date: 2026-01-16T02:12:00-03:00
session_name: general
researcher: Claude
git_commit: 9db7bfc
branch: main
repository: bitchat-flutter
topic: "BLE Messages Working - Minor Bugs Remain"
tags: [ble, mesh, messages, bugfix]
status: in_progress
last_updated: 2026-01-16
type: implementation_strategy
---

# Handoff: BLE Messages Working - Bugs to Fix

## Task(s)
1. **[COMPLETED]** Fix chat messages not received from Android
2. **[COMPLETED]** Fix Bluetooth timing issue on startup
3. **[NEW BUG]** Messages appear duplicated
4. **[NEW BUG]** Sender shows UID (813654e4...) instead of nickname (cquiroz)

## Root Cause Found & Fixed

### Problem: Android sends plain UTF-8, Flutter expected structured binary
- Android: `content.toByteArray(UTF-8)` → just "Hola" as bytes
- Flutter: Expected flags + timestamp + id + sender + content structure

### Fix Applied
Added UTF-8 fallback in `lib/data/models/bitchat_message.dart:152-180`:
```dart
// Fallback: Android sends plain UTF-8 text as payload
try {
  final content = utf8.decode(data, allowMalformed: false);
  return BitchatMessage(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    sender: '', // Filled by caller from packet senderID
    content: content,
    ...
  );
}
```

### Bluetooth Timing Fix
Added wait loop in `lib/features/mesh/bluetooth_mesh_service.dart:122-138`:
```dart
while (bleManager.state != BluetoothLowEnergyState.poweredOn && attempts < 10) {
  await Future.delayed(Duration(milliseconds: 500));
  attempts++;
}
```

## Remaining Bugs

### 1. Duplicate Messages
**Symptom:** Same message appears multiple times in UI
**Likely Cause:** Message received via both:
- GATT Server (when Android writes to Flutter's characteristic)
- GATT Client (when Flutter reads notifications from Android)

**Fix Location:** `lib/features/chat/chat_provider.dart` - need deduplication by message ID

### 2. Wrong Sender Name
**Symptom:** Shows UID `813654e4c15d2c8d` instead of nickname `cquiroz`
**Cause:** `BitchatMessage.sender` is set to peerID, not looked up from PeerManager

**Fix Location:** `lib/features/mesh/bluetooth_mesh_service.dart:540-545`
```dart
// Current (wrong):
sender: msg.sender.isEmpty ? peerID : msg.sender,

// Should be:
final peer = peerManager.getPeer(peerID);
sender: peer?.name ?? peerID,
```

## Files Changed This Session
- `lib/data/models/bitchat_message.dart:152-180` - UTF-8 fallback
- `lib/features/mesh/bluetooth_mesh_service.dart:122-138` - BT wait loop
- `lib/features/mesh/bluetooth_mesh_service.dart:478-493` - Debug logging
- `lib/features/mesh/bluetooth_mesh_service.dart:529-560` - Chat message processing

## Verification Logs
```
Processing packet type 0x2 from 813654e4c15d2c8d, payload: 4 bytes
Decoding chat message payload: 4 bytes
Chat message from 813654e4c15d2c8d: "Hola"
[ChatNotifier] didReceiveMessage: Hola
```

## Action Items

### Quick Fixes (5 min each)
1. **Fix sender name** - Look up nickname from PeerManager in `_processChatMessage`
2. **Add deduplication** - Track seen message IDs in ChatProvider, skip duplicates

### Still Pending
3. **Android no ve Flutter** - Verify if advertising is working bidirectionally
4. **Private chat UI** - Enable selecting peer for DM

## Testing Commands
```bash
# Rebuild and install
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Watch message logs
adb logcat -v time | grep -E "(flutter.*Chat message|flutter.*didReceive)"
```
