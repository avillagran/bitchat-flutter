# BitChat Flutter Migration - Tasks Part 2 (Phases 8-13)

**Original Codebase:** `/Users/avillagran/Desarrollo/bitchat-android` (~60,000 LOC)

---

## PHASE 8: Nostr Integration (Weeks 12-14)

### Task 8.1: Implement NostrClient & WebSocket Manager
**User Story:** US-014 (Geohash channels)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] NostrClient class with:
  - connect(relayUrl)
  - disconnect()
  - publishEvent(event)
  - subscribe(filters)
- [ ] WebSocket reconnection logic
- [ ] Multiple relay support (pool)
- [ ] Connection state management
- [ ] Error handling and retries

**Files:**
- `lib/features/nostr/nostr_client.dart`
- `lib/features/nostr/relay_manager.dart`

**Relay URLs (default):**
- wss://relay.damus.io
- wss://nos.lol
- wss://relay.snort.social

---

### Task 8.2: Implement NIP-01 Event Creation & Validation
**User Story:** US-014 (Geohash channels), US-015 (Location notes)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] NostrEvent model (NIP-01 compliant):
  - id (SHA-256 hash)
  - pubkey (hex)
  - created_at (Unix timestamp)
  - kind (0-40000)
  - tags (2D array)
  - content (string)
  - sig (Schnorr signature)
- [ ] createEvent method
- [ ] verifyEvent signature
- [ ] Event serialization (JSON canonical)

**Files:**
- `lib/features/nostr/models/nostr_event.dart`
- `lib/features/nostr/services/event_builder.dart`

---

### Task 8.3: Implement NIP-17 Gift Wrap (Private DM)
**User Story:** US-014 (Private geohash messages)  
**Priority:** P1  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] NIP-17 gift wrap implementation:
  - Kind 1059 (gift wrap)
  - Kind 14 (chat message)
  - Seal and gift wrap structure
- [ ] Ephemeral key generation
- [ ] NIP-44 encryption (updated from NIP-04)
- [ ] Rumor (unsigned event) support
- [ ] Unwrap and decrypt received events

**Files:**
- `lib/features/nostr/services/nip17_service.dart`
- `lib/features/nostr/crypto/nip44_encryption.dart`

**Reference:** https://github.com/nostr-protocol/nips/blob/master/17.md

---

### Task 8.4: Implement Geohash Encoding & Channels
**User Story:** US-014 (Geohash channels), US-016 (Bookmark channels)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] GeohashService class:
  - encode(lat, lng, precision) → geohash string
  - decode(geohash) → (lat, lng)
  - neighbors(geohash) → List<String>
- [ ] GeohashChannelManager:
  - joinChannel(geohash)
  - leaveChannel(geohash)
  - getChannelMessages(geohash)
  - bookmarkChannel(geohash)
- [ ] Precision: 6 characters (~1.2 km²)
- [ ] Auto-join based on current location

**Files:**
- `lib/features/geohash/services/geohash_service.dart`
- `lib/features/geohash/managers/geohash_channel_manager.dart`

---

### Task 8.5: Implement Nostr Subscription & Filtering
**User Story:** US-014 (Geohash channels)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] NostrSubscription class
- [ ] Filter support (NIP-01):
  - ids
  - authors
  - kinds
  - #e, #p, #t tags
  - since, until
  - limit
- [ ] REQ/CLOSE message handling
- [ ] Event deduplication
- [ ] Subscription lifecycle management

**Files:**
- `lib/features/nostr/models/nostr_filter.dart`
- `lib/features/nostr/services/subscription_manager.dart`

---

### Task 8.6: Nostr Integration Tests
**User Story:** US-014 (Geohash channels)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] Connect to public relay test
- [ ] Publish kind 1 event test
- [ ] Subscribe and receive events test
- [ ] NIP-17 gift wrap/unwrap test
- [ ] Geohash channel join/post/receive test
- [ ] Interop with Android app via Nostr relay

**Files:**
- `test/integration/nostr_test.dart`
- `docs/NOSTR_INTEROP_TEST.md`

---

## PHASE 9: Geohash & Location Features (Weeks 14-15)

### Task 9.1: Implement Geohash UI Components
**User Story:** US-014 (Geohash channels), US-015 (Location notes)  
**Priority:** P0  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] LocationChannelsSheet bottom sheet:
  - Current location geohash display
  - Nearby channels list
  - Join/leave buttons
  - Bookmarks section
- [ ] GeohashPicker widget:
  - Map view (optional: use flutter_map)
  - Geohash grid overlay
  - Tap to select geohash
  - Current location button
- [ ] Channel message list UI

**Files:**
- `lib/features/geohash/widgets/location_channels_sheet.dart`
- `lib/features/geohash/widgets/geohash_picker.dart`
- `lib/features/geohash/widgets/channel_message_list.dart`

---

### Task 9.2: Implement Location Notes Feature
**User Story:** US-015 (Location notes)  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] LocationNotesSheet for viewing nearby notes
- [ ] Create location note dialog
- [ ] Note types:
  - Public (kind 1, visible to all)
  - Ephemeral (short TTL)
- [ ] Notes include:
  - Content (max 280 chars)
  - Geohash tag
  - Timestamp
  - Author pubkey
- [ ] Map view showing note pins (optional)

**Files:**
- `lib/features/geohash/widgets/location_notes_sheet.dart`
- `lib/features/geohash/widgets/create_note_dialog.dart`

---

### Task 9.3: Implement Geohash Channel Bookmarks
**User Story:** US-016 (Bookmark channels)  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] Bookmark storage in Hive channels_box
- [ ] BookmarkManager:
  - addBookmark(geohash, name)
  - removeBookmark(geohash)
  - getBookmarks() → List<BookmarkedChannel>
- [ ] Quick access from main screen
- [ ] Sync bookmarks across devices (optional via Nostr)

**Files:**
- `lib/features/geohash/managers/bookmark_manager.dart`
- `lib/features/geohash/widgets/bookmarks_list.dart`

---

### Task 9.4: Geohash Auto-Update Service
**User Story:** US-014 (Geohash channels)  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] GeohashAutoUpdateService:
  - Monitor location changes
  - Auto-leave old geohash channels
  - Auto-join new geohash channels
  - Configurable update threshold (e.g., 500m)
- [ ] Background location updates (with permission)
- [ ] Battery-efficient tracking

**Files:**
- `lib/features/geohash/services/geohash_auto_update_service.dart`

---

## PHASE 10: Media Features (Weeks 15-16)

### Task 10.1: Implement Voice Recording & Playback
**User Story:** US-017 (Voice messages)  
**Priority:** P0  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] VoiceRecorderWidget:
  - Hold-to-record button
  - Recording duration display
  - Waveform visualization
  - Cancel/send actions
- [ ] Audio encoding: Opus or AAC
- [ ] Max duration: 5 minutes
- [ ] File size limit: 5MB
- [ ] VoiceMessageBubble:
  - Playback controls
  - Waveform display
  - Duration label
- [ ] Background recording support

**Files:**
- `lib/features/chat/widgets/voice_recorder_widget.dart`
- `lib/features/chat/widgets/voice_message_bubble.dart`
- `lib/features/chat/services/audio_recorder_service.dart`

**Dependencies:**
- record: ^5.0.0
- audioplayers: ^6.0.0

---

### Task 10.2: Implement Image Picker & Compression
**User Story:** US-018 (Send images)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] Image picker integration (camera + gallery)
- [ ] ImageCompressionService:
  - Max resolution: 1920x1080
  - Quality: 85%
  - Format: JPEG
  - Max size: 2MB after compression
- [ ] ImageMessageBubble:
  - Thumbnail display
  - Tap to view full-screen
  - Loading indicator during transfer
- [ ] Full-screen image viewer with zoom

**Files:**
- `lib/features/chat/services/image_compression_service.dart`
- `lib/features/chat/widgets/image_message_bubble.dart`
- `lib/features/chat/widgets/image_viewer.dart`

**Dependencies:**
- image_picker: ^1.0.0
- image: ^4.0.0 (for compression)

---

### Task 10.3: Implement File Picker & Transfer
**User Story:** US-019 (Send files with progress)  
**Priority:** P1  
**Effort:** 10h

**Acceptance Criteria:**
- [ ] File picker integration
- [ ] Supported types: PDF, TXT, DOC, ZIP
- [ ] Max file size: 10MB
- [ ] FileTransferManager:
  - Chunked transfer (via fragmentation)
  - Progress tracking (bytes sent/total)
  - Pause/resume capability
  - Transfer queue
- [ ] FileMessageBubble:
  - File icon by type
  - File name and size
  - Download button
  - Progress bar during transfer

**Files:**
- `lib/features/chat/services/file_transfer_manager.dart`
- `lib/features/chat/widgets/file_message_bubble.dart`

**Dependencies:**
- file_picker: ^8.0.0

---

### Task 10.4: Media Storage & Cache Management
**User Story:** US-017, US-018, US-019  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] MediaStorageService:
  - Save media to app directory
  - Organize by type (audio/, images/, files/)
  - Unique filename generation
  - Cache size limit: 500MB
  - Auto-cleanup old files (LRU)
- [ ] getThumbnail for images/videos
- [ ] Media gallery view (optional)

**Files:**
- `lib/features/chat/services/media_storage_service.dart`

---

## PHASE 11: Verification & Security (Weeks 16-17)

### Task 11.1: Implement QR Code Generation & Scanning
**User Story:** US-010 (Verify identity via QR)  
**Priority:** P0  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] QR code generation for own public key:
  - Format: `bitchat://verify/{pubkey_hex}`
  - Display in VerificationScreen
- [ ] QR scanner:
  - Camera access
  - Scan and parse bitchat:// URLs
  - Auto-verify after scan
- [ ] Visual feedback (success/error)

**Files:**
- `lib/features/verification/widgets/qr_display_widget.dart`
- `lib/features/verification/widgets/qr_scanner_widget.dart`

**Dependencies:**
- qr_flutter: ^4.1.0
- mobile_scanner: ^5.0.0

---

### Task 11.2: Implement Fingerprint Comparison UI
**User Story:** US-011 (Compare fingerprints)  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] FingerprintComparisonSheet:
  - Display own fingerprint (SHA-256 of pubkey)
  - Display peer's fingerprint
  - Visual comparison (highlight matches)
  - Manual verify button
- [ ] Fingerprint format: `XXXX XXXX XXXX XXXX` (16 hex chars, 4 groups)
- [ ] Copy to clipboard button

**Files:**
- `lib/features/verification/widgets/fingerprint_comparison_sheet.dart`

---

### Task 11.3: Implement Verification Flow & State
**User Story:** US-010 (Verify identity)  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] VerificationScreen with tabs:
  - QR Code (show own)
  - Scanner (scan peer's)
  - Manual (fingerprint comparison)
- [ ] VerificationManager:
  - verifyPeer(peerId, method)
  - unverifyPeer(peerId)
  - getVerifiedPeers() → List<Peer>
- [ ] Verification badge in peer list
- [ ] Verification status persistence

**Files:**
- `lib/features/verification/screens/verification_screen.dart`
- `lib/features/verification/managers/verification_manager.dart`

---

### Task 11.4: Implement Secure Delete & Emergency Wipe
**User Story:** US-012 (Emergency wipe)  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] SecureDeleteService:
  - overwriteFile(path, passes: 3)
  - deleteFile(path)
  - wipeDirectory(path)
- [ ] EmergencyWipeManager:
  - wipeAllData()
  - Actions:
    1. Stop all services
    2. Disconnect all peers
    3. Secure delete Hive boxes
    4. Clear flutter_secure_storage
    5. Clear app cache
    6. Reset to onboarding
- [ ] Wipe confirmation (type "DELETE")
- [ ] Cannot be undone warning

**Files:**
- `lib/core/services/secure_delete_service.dart`
- `lib/features/settings/services/emergency_wipe_manager.dart`

---

### Task 11.5: Implement Peer Blocking
**User Story:** US-013 (Block malicious peers)  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] BlockManager:
  - blockPeer(peerId)
  - unblockPeer(peerId)
  - isBlocked(peerId) → bool
  - getBlockedPeers() → List<Peer>
- [ ] Blocked peers:
  - Cannot connect
  - Messages dropped
  - Not shown in peer list
- [ ] Block list UI in settings
- [ ] Block reason (optional)

**Files:**
- `lib/features/settings/managers/block_manager.dart`
- `lib/features/settings/screens/blocked_peers_screen.dart`

---

## PHASE 12: Tor/Arti FFI Integration (Weeks 17-18)

### Task 12.1: Setup Rust Project & flutter_rust_bridge
**User Story:** US-023 (Optional Tor routing)  
**Priority:** P1  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] Create `rust/` directory with Cargo project
- [ ] Add Arti dependencies to `Cargo.toml`:
  - arti-client
  - tor-rtcompat
  - tokio
- [ ] Configure flutter_rust_bridge codegen
- [ ] Setup cross-compilation targets:
  - Android: aarch64-linux-android, armv7-linux-androideabi, x86_64-linux-android
  - iOS: aarch64-apple-ios, x86_64-apple-ios
- [ ] Build scripts for each platform

**Files:**
- `rust/Cargo.toml`
- `rust/src/lib.rs`
- `build.sh` (cross-compile script)

**Reference:** Arti docs at https://gitlab.torproject.org/tpo/core/arti

---

### Task 12.2: Implement Arti Wrapper in Rust
**User Story:** US-023 (Optional Tor routing)  
**Priority:** P1  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] Rust functions:
  - `arti_init(config_dir: String) -> Result<ArtiBridge>`
  - `arti_connect(addr: String, port: u16) -> Result<Stream>`
  - `arti_shutdown() -> Result<()>`
  - `arti_get_status() -> Status`
- [ ] Bootstrap progress callbacks
- [ ] SOCKS5 proxy mode
- [ ] Circuit management
- [ ] Error handling (Rust → Dart)

**Files:**
- `rust/src/arti_bridge.rs`

---

### Task 12.3: Generate Dart Bindings
**User Story:** US-023 (Optional Tor routing)  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] Run flutter_rust_bridge_codegen
- [ ] Generated Dart classes:
  - ArtiBridge
  - ArtiStatus
  - ArtiError
- [ ] FFI setup in main.dart
- [ ] Platform-specific library loading

**Files:**
- `lib/features/tor/ffi/arti_bridge.dart` (generated)
- `lib/features/tor/arti_service.dart` (wrapper)

---

### Task 12.4: Integrate Tor Proxy with Networking Layer
**User Story:** US-023 (Optional Tor routing)  
**Priority:** P1  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] TorProxyService:
  - initialize()
  - connect()
  - getProxyUrl() → String (socks5://127.0.0.1:9050)
- [ ] HTTP client with Tor support:
  - Use proxy for Nostr WebSocket connections
  - Tor-only mode (optional setting)
- [ ] Bootstrap progress UI
- [ ] Tor status indicator

**Files:**
- `lib/features/tor/services/tor_proxy_service.dart`
- `lib/features/tor/widgets/tor_status_indicator.dart`

---

### Task 12.5: Create Build Flavors (Full vs Lite)
**User Story:** US-023 (Optional Tor)  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] Build flavors:
  - `full`: Includes Arti (~40MB larger)
  - `lite`: Excludes Arti (smaller binary)
- [ ] Conditional compilation:
  - `--dart-define=FLAVOR=full`
- [ ] Flavor-specific builds:
  ```bash
  flutter build apk --flavor full --release
  flutter build apk --flavor lite --release
  ```
- [ ] Documentation for flavor selection

**Files:**
- `android/app/build.gradle` (flavor config)
- `docs/BUILD_FLAVORS.md`

---

### Task 12.6: CI/CD for Cross-Compilation
**User Story:** US-023 (Optional Tor)  
**Priority:** P1  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] GitHub Actions workflow:
  - Install Rust toolchain
  - Add cross-compile targets
  - Build Rust libraries for all platforms
  - Run flutter build
  - Artifact upload (APK/IPA)
- [ ] Caching for Rust build
- [ ] Separate jobs for full/lite flavors

**Files:**
- `.github/workflows/build_tor.yml`

---

## PHASE 13: Testing, Optimization & Release Prep (Weeks 18-20)

### Task 13.1: Unit Tests Coverage
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 16h

**Acceptance Criteria:**
- [ ] Unit tests for all critical modules:
  - Protocol (codec, fragmentation): 90%+
  - Crypto (Noise, primitives): 95%+
  - Nostr (events, NIP-17): 85%+
  - Geohash: 80%+
  - State management: 80%+
- [ ] Mocking with mockito/mocktail
- [ ] Test coverage report >80% overall
- [ ] CI fails on coverage drop

**Files:**
- `test/**/*_test.dart`
- `.github/workflows/ci.yml` (coverage check)

---

### Task 13.2: Widget Tests
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] Widget tests for:
  - ChatScreen
  - MessageBubble
  - ChatInputBar
  - PeerListSheet
  - OnboardingFlow
  - VerificationScreen
- [ ] Test interactions (tap, long-press, scroll)
- [ ] Test theme variations (light/dark)
- [ ] Golden tests for key screens (optional)

**Files:**
- `test/features/*/widgets/*_test.dart`

---

### Task 13.3: Integration Tests
**User Story:** All user stories  
**Priority:** P0  
**Effort:** 16h

**Acceptance Criteria:**
- [ ] End-to-end test scenarios:
  - Onboarding flow
  - Send/receive text message
  - Voice message recording/playback
  - Image send/receive
  - QR verification
  - Geohash channel join/post
  - Emergency wipe
- [ ] Real device tests (BLE requires hardware)
- [ ] Android ↔ Flutter interop tests
- [ ] Test report with screenshots/videos

**Files:**
- `integration_test/app_test.dart`
- `docs/INTEGRATION_TEST_REPORT.md`

---

### Task 13.4: Performance Profiling & Optimization
**User Story:** Technical foundation  
**Priority:** P1  
**Effort:** 12h

**Acceptance Criteria:**
- [ ] Profile bottlenecks:
  - Crypto operations (target <10ms per op)
  - BLE message handling (target <50ms latency)
  - UI rendering (target 60 FPS)
- [ ] Optimize heavy operations:
  - Consider FFI for crypto hotspots if needed
  - Message list pagination
  - Image loading/caching
- [ ] Memory leak checks (DevTools)
- [ ] Performance report

**Files:**
- `docs/PERFORMANCE_REPORT.md`

---

### Task 13.5: Battery Usage Optimization
**User Story:** US-003 (Background operation)  
**Priority:** P1  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] Battery usage tests (24h background):
  - Target: <5% battery drain per hour
- [ ] Optimizations:
  - Adaptive scan intervals (implemented in 4.6)
  - Coalesce BLE operations
  - Wake lock management
  - Reduce background network usage
- [ ] Battery testing report

**Files:**
- `docs/BATTERY_TEST_REPORT.md`

---

### Task 13.6: Accessibility Checks
**User Story:** Technical foundation  
**Priority:** P1  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] Semantic labels for all interactive widgets
- [ ] Screen reader testing (TalkBack, VoiceOver)
- [ ] Sufficient color contrast (WCAG AA)
- [ ] Font scaling support
- [ ] Keyboard navigation (desktop)
- [ ] Accessibility audit report

**Files:**
- `docs/ACCESSIBILITY_AUDIT.md`

---

### Task 13.7: Error Handling & Crash Reporting
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] Global error handler (FlutterError.onError)
- [ ] Crash reporting integration:
  - Option 1: Sentry
  - Option 2: Firebase Crashlytics
- [ ] Error logging with context
- [ ] User-friendly error messages
- [ ] Offline error queue

**Files:**
- `lib/core/services/error_service.dart`
- `lib/core/services/crash_reporting_service.dart`

---

### Task 13.8: Logging & Diagnostics
**User Story:** Technical foundation  
**Priority:** P1  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] Structured logging (logger package)
- [ ] Log levels: debug, info, warning, error
- [ ] Log rotation (max 7 days)
- [ ] In-app log viewer (debug builds only)
- [ ] Export logs feature for support

**Files:**
- `lib/core/services/logging_service.dart`
- `lib/features/settings/screens/logs_screen.dart`

---

### Task 13.9: Documentation
**User Story:** Technical foundation  
**Priority:** P1  
**Effort:** 8h

**Acceptance Criteria:**
- [ ] User documentation:
  - Getting started guide
  - Feature tutorials
  - FAQ
  - Privacy policy
  - Terms of service
- [ ] Developer documentation:
  - Architecture overview
  - Contributing guide
  - API reference (generated)
  - Build instructions
- [ ] In-app help sections

**Files:**
- `docs/USER_GUIDE.md`
- `docs/ARCHITECTURE.md`
- `docs/CONTRIBUTING.md`
- `PRIVACY_POLICY.md`
- `TERMS_OF_SERVICE.md`

---

### Task 13.10: Beta Testing Preparation
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 6h

**Acceptance Criteria:**
- [ ] Beta testing plan:
  - Recruit 20-50 beta testers
  - Test scenarios documented
  - Feedback form (Google Forms / Typeform)
- [ ] Beta builds:
  - Android: Internal testing track (Google Play Console)
  - iOS: TestFlight setup
- [ ] Beta release notes
- [ ] Support channel setup (Telegram/Discord)

**Files:**
- `docs/BETA_TEST_PLAN.md`
- `RELEASE_NOTES.md`

---

### Task 13.11: Production Release Checklist
**User Story:** Technical foundation  
**Priority:** P0  
**Effort:** 4h

**Acceptance Criteria:**
- [ ] Release checklist completed:
  - All P0 tasks done
  - All tests passing
  - Performance benchmarks met
  - Accessibility audit passed
  - Legal docs reviewed (privacy, terms)
  - App store assets ready (screenshots, descriptions)
  - Crash reporting enabled
  - Analytics configured (opt-in)
- [ ] Version bump (1.0.0)
- [ ] Release notes finalized
- [ ] App store submissions:
  - Google Play Store
  - Apple App Store

**Files:**
- `docs/RELEASE_CHECKLIST.md`

---

## Summary Statistics

**Total Tasks:** 115+ across 13 phases  
**Estimated Effort:** 450-520 hours (16-20 weeks at 25-30h/week)  
**User Stories Covered:** All 26 user stories from PRD  

**Priority Breakdown:**
- P0 (Critical): 70 tasks
- P1 (High): 45 tasks

**Phase Effort Distribution:**
- Phase 1-3 (Foundation): 20%
- Phase 4-5 (BLE & Core): 25%
- Phase 6-7 (UI & Onboarding): 15%
- Phase 8-9 (Nostr & Geohash): 15%
- Phase 10-12 (Media & Advanced): 15%
- Phase 13 (Testing & Release): 10%

---

## Next Steps

1. **Setup Development Environment:**
   ```bash
   cd /Users/avillagran/Desarrollo/bitchat-flutter
   fvm install 3.27.4
   fvm use 3.27.4
   fvm flutter doctor
   ```

2. **Create GitHub Issues:**
   - Import tasks as GitHub issues
   - Label by phase and priority
   - Assign to milestones

3. **Start Phase 1:**
   - Begin with Task 1.1 (FVM setup)
   - Follow task order sequentially within each phase

4. **Track Progress:**
   - Update task checklist as work completes
   - Review original codebase at `/Users/avillagran/Desarrollo/bitchat-android` for reference
   - Test against Android app for compatibility

---

**END OF TASKS DOCUMENT**
