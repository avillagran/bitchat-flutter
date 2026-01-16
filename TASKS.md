# BitChat Flutter Migration - Tasks & User Stories

**Original Codebase:** `/Users/avillagran/Desarrollo/bitchat-android` (~60,000 LOC)  
**Target:** Cross-platform Flutter app (iOS, Android, desktop)  
**Duration:** 16-20 weeks (Mobile MVP)

---

## PHASE 1: Setup & Infrastructure (Weeks 1-2)

### Task 1.1: Initialize Flutter Project with FVM
**User Story:** US-026 (Multi-language support)  
**Priority:** P0  
**Effort:** 2h

**Acceptance Criteria:**
- [ ] FVM 3.27.4 installed and configured
- [ ] `.fvmrc` file created
- [ ] Project builds successfully on macOS
- [ ] `flutter doctor` shows no critical issues

**Commands:**
```bash
fvm install 3.27.4
fvm use 3.27.4
fvm flutter doctor
```

---

### Task 1.2: Create Base Folder Structure
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 1h

**Acceptance Criteria:**
- [ ] Folder structure matches PLAN.md specification
- [ ] README.md with contribution guidelines created
- [ ] .gitignore configured for Flutter/Dart

**Structure:**
```
lib/
├── core/
├── config/
├── data/
├── domain/
├── features/{onboarding,chat,mesh,crypto,nostr,geohash,tor}/
├── protocol/
└── l10n/
```

---

### Task 1.3: Configure pubspec.yaml Dependencies
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 2h

**Acceptance Criteria:**
- [ ] All core dependencies added:
  - flutter_riverpod ^2.4.0
  - flutter_blue_plus ^1.32.0
  - hive ^2.2.3
  - flutter_secure_storage ^9.0.0
  - pointycastle ^3.7.3
  - cryptography ^2.5.0
  - go_router ^13.0.0
- [ ] Dev dependencies configured
- [ ] `flutter pub get` runs without errors

---

### Task 1.4: Setup Riverpod State Management
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 3h

**Acceptance Criteria:**
- [ ] ProviderScope configured in main.dart
- [ ] Example StateNotifier created
- [ ] riverpod_generator configured with build_runner
- [ ] Basic provider structure documented

**Files:**
- `lib/main.dart`
- `lib/core/providers/app_providers.dart`

---

### Task 1.5: Configure Hive & Secure Storage
**User Story:** US-009 (E2E encryption), US-012 (Emergency wipe)  
**Priority:** P0  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] Hive initialized with 5 boxes:
  - messages_box (encrypted)
  - peers_box
  - channels_box
  - identity_box (encrypted)
  - settings_box
- [ ] flutter_secure_storage integrated for key storage
- [ ] Encryption adapters configured
- [ ] Unit tests for storage operations

**Files:**
- `lib/data/local/hive_service.dart`
- `lib/data/local/secure_storage_service.dart`

---

### Task 1.6: Setup Internationalization (i18n)
**User Story:** US-026 (Multi-language support)  
**Priority:** P1  
**Effort:** 3h

**Acceptance Criteria:**
- [ ] `flutter_localizations` configured
- [ ] `app_en.arb` created with ~50 core strings
- [ ] Template ARB file for 34 languages prepared
- [ ] l10n.yaml configured
- [ ] Code generation works (`flutter gen-l10n`)

**Files:**
- `lib/l10n/app_en.arb`
- `l10n.yaml`

---

### Task 1.7: Configure Themes & Router
**User Story:** US-025 (Light/dark theme)  
**Priority:** P1  
**Effort:** 3h

**Acceptance Criteria:**
- [ ] ThemeData for light/dark modes defined
- [ ] go_router configured with 5 base routes:
  - /splash
  - /onboarding
  - /chat
  - /settings
  - /verification
- [ ] ThemeMode provider with persistence
- [ ] Navigation transitions configured

**Files:**
- `lib/config/theme.dart`
- `lib/config/router.dart`

---

### Task 1.8: Setup CI/CD Pipeline
**User Story:** Technical foundation  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] GitHub Actions workflow created
- [ ] FVM support in CI
- [ ] flutter analyze check
- [ ] flutter format check
- [ ] Unit tests run on push
- [ ] Build APK artifact on main branch

**Files:**
- `.github/workflows/ci.yml`

---

## PHASE 2: Data Models & Binary Protocol (Weeks 2-3)

### Task 2.1: Define Core Data Models with Freezed
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] Models created with freezed + json_serializable:
  - BitchatMessage (id, sender, recipient, content, timestamp, type, deliveryStatus)
  - Peer (id, publicKey, nickname, rssi, lastSeen, isVerified, isFavorite)
  - Channel (id, name, type, geohash, members)
  - Identity (keyPair, publicKeyHex, fingerprint)
  - RoutedPacket (header, payload, hops, ttl)
  - NostrEvent (NIP-01 compliant)
- [ ] Code generation works
- [ ] toJson/fromJson tested

**Files:**
- `lib/data/models/message.dart`
- `lib/data/models/peer.dart`
- `lib/data/models/channel.dart`
- `lib/data/models/identity.dart`
- `lib/data/models/routed_packet.dart`
- `lib/data/models/nostr_event.dart`

---

### Task 2.2: Implement Binary Protocol Header (13 bytes)
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] BinaryProtocol class with 13-byte header:
  - Version (1 byte)
  - Message Type (1 byte): HANDSHAKE, MESSAGE, ACK, PING, RELAY, CHANNEL
  - Flags (1 byte): ENCRYPTED, COMPRESSED, FRAGMENT
  - Packet ID (4 bytes)
  - Payload Length (2 bytes)
  - Checksum CRC32 (4 bytes)
- [ ] encode/decode methods
- [ ] Checksum validation
- [ ] Compatible with Android version

**Files:**
- `lib/protocol/binary_protocol.dart`
- `lib/protocol/message_types.dart`

**Reference:** Original protocol in `/Users/avillagran/Desarrollo/bitchat-android/app/src/main/java/com/bitchat/protocol/`

---

### Task 2.3: Implement Packet Codec & Fragmentation
**User Story:** US-001 (Send encrypted messages), US-018 (Send images)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] PacketCodec class with:
  - encode(message) → List<Uint8List> (fragments if >500 bytes)
  - decode(fragments) → message
  - MTU negotiation support (default 517)
- [ ] FragmentManager with reassembly logic
- [ ] Sequence numbers and timeouts
- [ ] Unit tests with payloads: 50B, 500B, 5KB, 50KB

**Files:**
- `lib/protocol/packet_codec.dart`
- `lib/protocol/fragment_manager.dart`

---

### Task 2.4: Implement Compression Utilities
**User Story:** US-018 (Image compression)  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] CompressionUtil class with:
  - compress(data, algorithm: deflate|lz4)
  - decompress(data)
  - Auto-detection of compression benefit (>20% size reduction)
- [ ] Performance benchmarks (compress 1MB in <500ms)
- [ ] Compatible with Android compression

**Files:**
- `lib/protocol/compression_util.dart`

---

### Task 2.5: Protocol Compatibility Tests
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] Unit tests for all message types
- [ ] Test vectors from Android app
- [ ] Serialization round-trip tests
- [ ] Interoperability test plan documented

**Files:**
- `test/protocol/binary_protocol_test.dart`
- `test/protocol/compatibility_test.dart`

---

## PHASE 3: Cryptography & Noise Protocol (Weeks 3-5)

### Task 3.1: Implement Cryptographic Primitives
**User Story:** US-009 (E2E encryption)  
**Priority:** P0  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] Curve25519 key exchange (pointycastle)
- [ ] ChaCha20-Poly1305 AEAD (cryptography package)
- [ ] SHA-256 hashing
- [ ] Ed25519 signatures for identity
- [ ] Unit tests with NIST test vectors
- [ ] Performance: <10ms for key exchange, <5ms for encrypt/decrypt

**Files:**
- `lib/features/crypto/primitives/curve25519.dart`
- `lib/features/crypto/primitives/chacha20_poly1305.dart`
- `lib/features/crypto/primitives/ed25519.dart`

---

### Task 3.2: Implement Noise Protocol XX Pattern
**User Story:** US-009 (E2E encryption), US-010 (Verify identity)  
**Priority:** P0  
**Effort:** 16h

**Acceptance Criteria:**
- [ ] NoiseSession class with XX handshake:
  - Noise_XX_25519_ChaChaPoly_SHA256
  - 3-message handshake (e, ee, s, es, se, ss)
- [ ] HandshakeState machine
- [ ] CipherState for encryption/decryption
- [ ] Session key derivation
- [ ] Compatible with Android implementation

**Files:**
- `lib/features/crypto/noise_session.dart`
- `lib/features/crypto/handshake_state.dart`
- `lib/features/crypto/cipher_state.dart`

**Reference:** `/Users/avillagran/Desarrollo/bitchat-android/.../NoiseProtocol.java`

---

### Task 3.3: Implement Replay Protection & Session Management
**User Story:** US-009 (E2E encryption security)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] SlidingWindowReplayProtection class:
  - 64-bit nonce tracking
  - Window size: 64 messages
- [ ] SessionManager with:
  - Session persistence to Hive
  - Key rotation (every 1000 messages)
  - Perfect Forward Secrecy
- [ ] Unit tests for replay attack scenarios

**Files:**
- `lib/features/crypto/replay_protection.dart`
- `lib/features/crypto/session_manager.dart`

---

### Task 3.4: Implement Nostr Cryptography (secp256k1/Schnorr)
**User Story:** US-014 (Geohash channels)  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] secp256k1 key generation
- [ ] Schnorr signatures (NIP-01)
- [ ] Event ID calculation (SHA-256)
- [ ] Compatible with existing Nostr clients
- [ ] Use existing package if available

**Files:**
- `lib/features/nostr/crypto/nostr_crypto.dart`

---

### Task 3.5: Crypto Interoperability Tests
**User Story:** US-009 (E2E encryption)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] Test Noise handshake: Flutter ↔ Android
- [ ] Test message encryption/decryption cross-platform
- [ ] Test session persistence and recovery
- [ ] Test key rotation
- [ ] Documented test protocol for manual verification

**Files:**
- `test/features/crypto/interop_test.dart`
- `docs/CRYPTO_INTEROP_TEST.md`

---

## PHASE 4: BLE Mesh Networking (Weeks 5-8)

### Task 4.1: Implement BluetoothMeshService Coordinator
**User Story:** US-005 (Discover peers), US-006 (Multi-hop relay)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] BluetoothMeshService singleton
- [ ] State management: disconnected, scanning, advertising, connected
- [ ] Integration with flutter_blue_plus
- [ ] Permission handling (Bluetooth, Location)
- [ ] Power state monitoring

**Files:**
- `lib/features/mesh/bluetooth_mesh_service.dart`
- `lib/features/mesh/mesh_state.dart`

---

### Task 4.2: Implement GATT Server (Peripheral Mode)
**User Story:** US-005 (Discover peers)  
**Priority:** P0  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] GattServerManager class
- [ ] Service UUID: `0000fd00-0000-1000-8000-00805f9b34fb`
- [ ] Characteristics:
  - TX (fd01): write, write-no-response
  - RX (fd02): read, notify
  - Control (fd03): read, write
- [ ] Advertising with device ID in scan response
- [ ] Compatible with Android GATT server

**Files:**
- `lib/features/mesh/gatt_server_manager.dart`

**Reference:** `/Users/avillagran/Desarrollo/bitchat-android/.../GattServer.java`

---

### Task 4.3: Implement GATT Client (Central Mode)
**User Story:** US-005 (Discover peers), US-007 (RSSI signal strength)  
**Priority:** P0  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] GattClientManager class
- [ ] Scanning with service UUID filter
- [ ] Connection management (max 7 concurrent on Android)
- [ ] MTU negotiation (target 517 bytes)
- [ ] RSSI monitoring
- [ ] Auto-reconnect logic
- [ ] Connection pooling

**Files:**
- `lib/features/mesh/gatt_client_manager.dart`
- `lib/features/mesh/connection_pool.dart`

---

### Task 4.4: Implement Peer Manager
**User Story:** US-005 (Discover peers), US-004 (Favorite contacts), US-013 (Block peers)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] PeerManager class with:
  - addPeer/removePeer/updatePeer
  - getPeerByPublicKey
  - getFavoritePeers
  - getBlockedPeers
  - isBlocked check
- [ ] Peer persistence to Hive
- [ ] Last-seen timestamp updates
- [ ] RSSI history (last 10 values)

**Files:**
- `lib/features/mesh/peer_manager.dart`
- `lib/data/repositories/peer_repository.dart`

---

### Task 4.5: Implement Message Handler & Relay Manager
**User Story:** US-001 (Send messages), US-006 (Multi-hop relay), US-008 (Store-and-forward)  
**Priority:** P0  
**Effort:** 14h

**Acceptance Criteria:**
- [ ] MessageHandler class:
  - onReceiveMessage
  - onSendMessage
  - Message deduplication (seen cache)
  - TTL processing
- [ ] PacketRelayManager:
  - Relay decision logic
  - Hop count tracking
  - Loop prevention
  - Relay queue with priority
- [ ] StoreForwardManager:
  - Queue messages for offline peers
  - Delivery on peer reconnection
  - TTL expiration cleanup

**Files:**
- `lib/features/mesh/message_handler.dart`
- `lib/features/mesh/packet_relay_manager.dart`
- `lib/features/mesh/store_forward_manager.dart`

---

### Task 4.6: Implement Power Manager & Adaptive Scanning
**User Story:** US-003 (Background notifications)  
**Priority:** P1  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] PowerManager class:
  - Battery level monitoring
  - Charging state detection
  - Battery saver mode detection
- [ ] Adaptive scan intervals:
  - Active (screen on): 30s
  - Idle (screen off): 300s
  - Battery saver: 600s
  - Charging: 15s
- [ ] Background scan strategies (iOS vs Android)

**Files:**
- `lib/features/mesh/power_manager.dart`
- `lib/features/mesh/scan_strategy.dart`

---

### Task 4.7: BLE Mesh Integration Tests
**User Story:** US-006 (Multi-hop relay)  
**Priority:** P0  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] 2-device test: Flutter ↔ Flutter direct message
- [ ] 2-device test: Flutter ↔ Android direct message
- [ ] 3-device test: Flutter ↔ Flutter ↔ Android relay
- [ ] RSSI monitoring validation
- [ ] MTU negotiation test
- [ ] Reconnection test
- [ ] Test report documented

**Files:**
- `test/integration/mesh_test.dart`
- `docs/BLE_MESH_TEST_REPORT.md`

---

## PHASE 5: Core Services & Background (Weeks 8-9)

### Task 5.1: Implement Background Service
**User Story:** US-003 (Background notifications), US-006 (Multi-hop relay)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] Android: Foreground service with persistent notification
- [ ] iOS: Background modes configured (bluetooth-central, bluetooth-peripheral)
- [ ] Service keeps mesh active when app backgrounded
- [ ] Wake lock management
- [ ] Service lifecycle (start/stop)
- [ ] Battery optimization handling

**Files:**
- `lib/core/services/background_service.dart`
- `android/app/src/main/kotlin/.../BackgroundService.kt`
- `ios/Runner/Info.plist` (background modes)

---

### Task 5.2: Implement Notification Service
**User Story:** US-003 (Background notifications)  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] NotificationService class
- [ ] Channels: messages, mesh_status, system
- [ ] Notification actions: reply, mark_read
- [ ] Grouped notifications (per peer)
- [ ] Custom sounds
- [ ] Notification permission handling

**Files:**
- `lib/core/services/notification_service.dart`

---

### Task 5.3: Implement Permission Service
**User Story:** US-020 (Guided permissions)  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] PermissionService class
- [ ] Request flow for:
  - Bluetooth (Android 12+ requires BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
  - Location (required for BLE scanning)
  - Notifications
  - Battery optimization exclusion
- [ ] Permission status checking
- [ ] Rationale dialogs

**Files:**
- `lib/core/services/permission_service.dart`

---

### Task 5.4: Implement Location Service
**User Story:** US-014 (Geohash channels)  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] LocationService class
- [ ] getCurrentLocation (one-time)
- [ ] Location updates stream (for geohash tracking)
- [ ] Permission handling
- [ ] Accuracy: <100m

**Files:**
- `lib/core/services/location_service.dart`

---

### Task 5.5: Implement Secure Identity Storage
**User Story:** US-009 (E2E encryption), US-012 (Emergency wipe)  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] IdentityRepository class
- [ ] Store/retrieve Ed25519 keypair in platform keychain:
  - Android: Keystore
  - iOS: Keychain
- [ ] Fingerprint generation (hex format)
- [ ] Emergency wipe method (secure delete)
- [ ] Backup/restore capability

**Files:**
- `lib/data/repositories/identity_repository.dart`

---

## PHASE 6: Chat UI (Weeks 9-11)

### Task 6.1: Implement ChatScreen Layout
**User Story:** US-001 (Send messages), US-002 (Delivery indicators)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] ChatScreen widget with:
  - AppBar showing peer info (nickname, RSSI)
  - Message list (ListView with reverse scroll)
  - Chat input bar with TextField and send button
  - Pull-to-refresh for older messages
- [ ] Responsive design (keyboard handling)
- [ ] Smooth scroll animations

**Files:**
- `lib/features/chat/screens/chat_screen.dart`

---

### Task 6.2: Implement Message Bubbles
**User Story:** US-001 (Send messages), US-002 (Delivery indicators)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] MessageBubble widget with:
  - Alignment (sent: right, received: left)
  - Bubble colors (light/dark theme support)
  - Timestamp
  - Delivery status icons (sent, delivered, read)
  - Long-press menu (copy, forward, delete)
- [ ] Support for text, image, audio, file types
- [ ] Link detection and formatting

**Files:**
- `lib/features/chat/widgets/message_bubble.dart`
- `lib/features/chat/widgets/delivery_indicator.dart`

---

### Task 6.3: Implement Chat Input Bar
**User Story:** US-001 (Send messages), US-017 (Voice messages)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] ChatInputBar widget with:
  - Multiline TextField (auto-expand up to 4 lines)
  - Send button (disabled when empty)
  - Attachment button (image, file)
  - Voice record button (hold-to-record)
- [ ] Typing indicator
- [ ] Emoji picker integration
- [ ] Command autocomplete (/join, /msg, /who, /block)

**Files:**
- `lib/features/chat/widgets/chat_input_bar.dart`

---

### Task 6.4: Implement Chat Provider & State
**User Story:** US-001 (Send messages), US-004 (Favorites)  
**Priority:** P0  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] ChatProvider (Riverpod StateNotifier)
- [ ] ChatState with:
  - messages: List<BitchatMessage>
  - currentPeer: Peer?
  - deliveryStatus: Map<messageId, status>
  - isTyping: bool
- [ ] Methods:
  - sendMessage(content, type)
  - loadMessages(peerId)
  - markAsRead(messageId)
  - toggleFavorite(peerId)
- [ ] Persistence to Hive
- [ ] Real-time updates from mesh

**Files:**
- `lib/features/chat/providers/chat_provider.dart`
- `lib/features/chat/state/chat_state.dart`

---

### Task 6.5: Implement Command Processor
**User Story:** US-024 (Chat commands)  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] CommandProcessor class
- [ ] Commands:
  - `/join <geohash>` - Join location channel
  - `/msg <peer> <message>` - Direct message
  - `/who` - List nearby peers
  - `/block <peer>` - Block peer
  - `/unblock <peer>` - Unblock peer
  - `/help` - Show commands
- [ ] Command validation and error handling
- [ ] Autocomplete suggestions

**Files:**
- `lib/features/chat/services/command_processor.dart`

---

### Task 6.6: Implement Peer List Sheet
**User Story:** US-004 (Favorites), US-007 (RSSI signal)  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] PeerListSheet bottom sheet
- [ ] Peer tiles showing:
  - Nickname
  - RSSI indicator (signal bars)
  - Last seen
  - Favorite star
  - Verification badge
- [ ] Tap to open chat
- [ ] Long-press menu (verify, block, favorite)
- [ ] Sort: favorites first, then by RSSI

**Files:**
- `lib/features/chat/widgets/peer_list_sheet.dart`
- `lib/features/chat/widgets/peer_tile.dart`

---

### Task 6.7: Implement Emergency Wipe UI
**User Story:** US-012 (Emergency wipe)  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] Emergency wipe button in settings
- [ ] Confirmation dialog (require typing "DELETE")
- [ ] Progress indicator
- [ ] Wipe actions:
  - Delete all Hive boxes
  - Delete identity keys
  - Clear flutter_secure_storage
  - Reset app state
- [ ] Restart to onboarding after wipe

**Files:**
- `lib/features/settings/widgets/emergency_wipe_button.dart`

---

## PHASE 7: Onboarding (Weeks 11-12)

### Task 7.1: Implement Splash Screen
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 3h

**Acceptance Criteria:**
- [ ] SplashScreen with app logo
- [ ] Initialization checks:
  - Identity exists?
  - Permissions granted?
- [ ] Navigate to onboarding or chat
- [ ] Loading animation

**Files:**
- `lib/features/onboarding/screens/splash_screen.dart`

---

### Task 7.2: Implement Permission Explanation Screens
**User Story:** US-020 (Guided permissions), US-021 (Battery optimization)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] Multi-step onboarding flow:
  1. Welcome screen
  2. Bluetooth explanation + request
  3. Location explanation + request
  4. Notification explanation + request
  5. Battery optimization warning
- [ ] Visual explanations (illustrations)
- [ ] Skip capability (with warnings)
- [ ] PageView with indicators

**Files:**
- `lib/features/onboarding/screens/onboarding_flow_screen.dart`
- `lib/features/onboarding/widgets/permission_step.dart`

---

### Task 7.3: Implement Battery Optimization Screen
**User Story:** US-021 (Battery optimization)  
**Priority:** P0  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] BatteryOptimizationScreen with:
  - Explanation of why exclusion needed
  - Platform-specific instructions
  - "Open Settings" button
  - Verification check
- [ ] Platform channel to check/request exclusion

**Files:**
- `lib/features/onboarding/screens/battery_optimization_screen.dart`
- `android/app/src/main/kotlin/.../BatteryOptimizationManager.kt`

---

### Task 7.4: Implement Nickname Setup Screen
**User Story:** US-022 (Set nickname)  
**Priority:** P0  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] NicknameSetupScreen with:
  - TextField (max 32 chars)
  - Character validation (alphanumeric + spaces)
  - Random suggestion button
  - Continue button
- [ ] Identity generation (Ed25519 keypair)
- [ ] Save to identity_box
- [ ] Navigate to chat after completion

**Files:**
- `lib/features/onboarding/screens/nickname_setup_screen.dart`

---

### Task 7.5: Onboarding Flow Integration
**User Story:** US-020, US-021, US-022  
**Priority:** P0  
**Effort:** 3h

**Acceptance Criteria:**
- [ ] OnboardingCoordinator manages flow
- [ ] State persistence (resume if interrupted)
- [ ] Skip/back navigation handling
- [ ] Completion flag saved

**Files:**
- `lib/features/onboarding/onboarding_coordinator.dart`

---

**Continue to TASKS_PART2.md for Phases 8-13...**
