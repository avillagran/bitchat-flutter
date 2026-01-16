Title: Bitchat — Migration from bitchat-android to Flutter (bitchat-flutter)

Date: 2026-01-15
Author: Andrés Villagrán <andres@villagranquiroz.cl>
Primary code reference: /Users/avillagran/Desarrollo/bitchat-android

1. Executive Summary
- Objective: Migrate the existing native Android app (bitchat-android, ~60k LOC) to a single, maintainable Flutter codebase (bitchat-flutter) to support iOS and Android (MVP priority), with desktop targets (macOS, Windows, Linux) planned post‑MVP.
- Key goals: preserve protocol compatibility (binary header, BLE UUIDs, Noise parameters), achieve feature parity (mesh messaging, Noise-based encryption, Nostr/geohash integration, media transfers, QR verification), and enable cross-platform maintainability while keeping the mobile experience first-class.
- Estimated effort: 16–20 weeks for a mobile-first MVP; major technical risks include BLE GATT/peripheral support variance, cryptography portability, and Tor/Arti binary size and cross-compilation complexity.
- Primary stakeholders: Engineering (implementation), Product (prioritization & release), Security, QA, and Executive sponsors.

2. Scope
- In-scope (MVP, mobile-first):
  - Cross-platform Flutter app for Android and iOS: mesh messaging (BLE GATT server/client), Noise XX handshake, packet binary protocol, Nostr relay integration (NIP-01; adapt NIP-17), geohash-based channels, media (voice, images, files), identity verification (QR + fingerprint), background mesh maintenance and notifications, secure key storage, and initial Tor/Arti FFI integration as an optional flavor.
  - Translations scaffold (~34 languages) and accessibility baseline.
  - CI pipelines for Android/iOS builds and tests.
- Out-of-scope for MVP:
  - Desktop-first UI/desktop BLE intricacies (post-MVP phase).
  - Full Arti builds for all desktop targets (post-MVP cross-compile/CI enhancements).
  - Enterprise integrations beyond relays and basic telemetry.

3. Audiences and Document Purpose
- Engineers: detailed implementation plan, dependencies, protocol parameters, tests, and gating criteria.
- Product & Stakeholders: roadmap, milestones, success metrics, and risks.
- Executives: concise timeline, budget-significant risks, release decision points.
- This PRD balances high-level decisions with technical appendices to serve all audiences.

4. Success Criteria & Metrics
- Build: Flutter app successfully compiles and runs on Android and iOS (device + emulator where applicable).
- Interop: Mesh messages exchanged between Flutter and the original Android app (round-trip messaging, correct routing, header/parsing compatibility).
- Security: Noise XX handshake implemented and interoperable with Android; secure key storage for identities; QR verification and fingerprint comparison implemented.
- Features: Nostr geohash channels publish/subscribe successfully to public relays; media transfer (audio, image, files) works with progress reporting and integrity checks; background mesh maintenance with persistent notifications on Android.
- Quality: Unit, widget, and integration tests covering models, protocol codec, Noise handshake, and BLE flows; performance benchmarks for crypto and BLE operations meet baseline targets.
- UX: Onboarding flow reduces setup failures; basic accessibility checks passed.

5. High-level Timeline & Phases (MVP: 16–20 weeks)
- Phase 1: Setup & Infra (Weeks 1–2)
  - Deliverable: Initial Flutter project (FVM 3.27.x), repo structure, pubspec, linting, CI skeleton, ProviderScope sample, Hive + secure storage scaffolding, localization ARB template, theme & router basics.
- Phase 2: Models & Binary Protocol (Weeks 2–3)
  - Deliverable: Freezed models (BitchatMessage, Peer, Channel, Identity, RoutedPacket, NostrEvent) and PacketCodec with fragmentation/assembly and compression utilities; unit tests for cross-platform serialization compatibility.
- Phase 3: Cryptography & Noise (Weeks 3–5)
  - Deliverable: Curve25519/Ed25519, ChaCha20-Poly1305, SHA256 primitives via cryptography/pointycastle; Noise XX implementation, handshake state, replay protection, identity persistence; interoperable tests with Android.
- Phase 4: BLE Mesh (Weeks 5–8)
  - Deliverable: BluetoothMeshService, GattServerManager (peripheral), GattClientManager (central), PeerManager, FragmentManager, PacketRelayManager, StoreForwardManager; tests between Flutter devices and Android native.
- Phase 5: Background & Services (Weeks 8–9)
  - Deliverable: Foreground/background service on Android, notification channels, permission handling, battery optimization guidance, secure identity storage.
- Phase 6: Chat UI & Core Flows (Weeks 9–11)
  - Deliverable: ChatScreen, components, ChatProvider (Riverpod), command processing, delivery/read indicators, favorites and emergency wipe.
- Phase 7: Onboarding (Weeks 11–12)
  - Deliverable: Splash/init flow, permission checks, nickname/identity setup, onboarding UX.
- Phase 8: Nostr Integration (Weeks 12–14)
  - Deliverable: NostrClient, RelayManager (WebSocket), event creation/validation, NIP-17 adaptation for geohash, geohash subscriptions.
- Phase 9: Geohash & Location (Weeks 14–15)
  - Deliverable: Geohash encoding/decoding, LocationChannelManager, UI pickers and bookmarks.
- Phase 10: Media (Weeks 15–16)
  - Deliverable: Voice record/playback, image picking/compression/viewer, file picking with fragmentation and transfer progress.
- Phase 11: Verification & Security (Weeks 16–17)
  - Deliverable: QR generation/scan for verification, fingerprint comparison, emergency wipe secure delete procedures.
- Phase 12: Tor/Arti FFI (Weeks 17–18)
  - Deliverable: flutter_rust_bridge integration, Arti Rust project layout, Dart bindings, optional Tor flavor build scripts and cross-compile CI work.
- Phase 13: Tests, Optimization & Release Prep (Weeks 18–20)
  - Deliverable: Tests (unit/widget/integration), profiling and crypto/BLE perf optimizations, battery improvements, accessibility checks, crash reporting setup.
- Phase 14: Desktop Support (Post-MVP)
  - Deliverable: Responsive UI adaptation and per-platform BLE integration, tray/shortcut support.

6. Functional Requirements (MVP)
- FR-1: Packet Protocol Compatibility — implement binary header (13 bytes) and packet types compatible with existing Android implementation.
- FR-2: Fragmentation & Reassembly — support packet fragmentation for large payloads and reassembly across BLE MTU variants.
- FR-3: End-to-End Encryption — Noise_XX_25519_ChaChaPoly_SHA256 handshake for peer sessions; ephemeral keys and replay protection.
- FR-4: BLE Mesh — advertise and scan, accept connections as peripheral, central scanning/connection, MTU negotiation, GATT characteristics parallel to Android.
- FR-5: Persistent Identity — generate and persist identity keys securely (encrypted Hive or secure storage).
- FR-6: Nostr Relay Integration — publish/subscribe events, geohash channels compatible with NIP-17 extension; WebSocket reconnection and backoff.
- FR-7: Media Transfer — record audio, pick images/files, compress, fragment/transfer reliably with progress/resume.
- FR-8: Onboarding — permission explanation, battery optimization guidance, identity creation.
- FR-9: Background Operation — maintain mesh connectivity and message handling in background with persistent notifications on Android.
- FR-10: Verification — QR code-based identity exchange and fingerprint matching flow.

7. Non-functional Requirements
- NFR-1: Cross-platform portability — prefer pure Dart crypto implementations where feasible; justify FFI if necessary for performance/interoperability.
- NFR-2: Performance — handshake latency and crypto operations to be optimized; memory footprint acceptable for mid-range devices.
- NFR-3: Security — keys encrypted at rest, secure transport, robustness against replay attacks, and secure deletion for emergency wipe.
- NFR-4: Testability — unit tests for codecs/crypto, widget tests for UI, integration tests for mesh flows; CI to run tests.
- NFR-5: Maintainability — use Riverpod, freezed, clear package structure, documented design decisions in PLAN.md.
- NFR-6: Observability — structured logging, optional telemetry respecting privacy, crash reporting for beta.

8. Architecture & Technical Decisions (summary)
- Flutter version managed with FVM 3.27.x; project created with fvm flutter create.
- State management: Riverpod (type-safe, testable).
- BLE: flutter_blue_plus with platform-channel fallbacks for missing peripheral features.
- Crypto: cryptography / pointycastle for Curve25519, ChaCha20-Poly1305, Ed25519; consider FFI for secp256k1 if required by Nostr libraries.
- Storage: Hive + encrypted_hive for local data; flutter_secure_storage for keys or keywrap where appropriate.
- Nostr: use and extend existing Dart nostr packages; adapt NIP-17 for geohash channels.
- Tor: integrate Arti via flutter_rust_bridge with a separate rust/ directory containing cargo project.
- Routing/UI: go_router; UI patterns: declarative widgets + hooks where useful.

9. Dependencies (pubspec snapshot)
- Runtime: flutter_riverpod, flutter_blue_plus, hive, hive_flutter, flutter_secure_storage, pointycastle, cryptography, nostr (or similar), web_socket_channel, freezed_annotation, json_annotation, go_router, flutter_hooks, record/audioplayers, image_picker/file_picker, mobile_scanner/qr_flutter, geolocator, permission_handler, flutter_local_notifications, flutter_background_service, http, uuid, intl, ffi/flutter_rust_bridge.
- Dev: build_runner, freezed, json_serializable, riverpod_generator, mockito/mocktail, flutter_lints.

10. Acceptance Criteria (per phase)
- Phase acceptance requires: green unit tests for implemented modules, successful interop tests with Android for critical interfaces (protocol, Noise handshake, BLE messaging), and UI flows validated on device(s).
- Final MVP acceptance: all success criteria in Section 4 met; QA sign-off after integration tests and a closed beta with at least 10 devices across Android/iOS demonstrating mesh connectivity, media transfer, and Nostr geohash functionality.

11. Risks & Mitigations
- RISK: Limited GATT Server/peripheral support in flutter_blue_plus (iOS and some Android OEMs).
  - Mitigation: implement platform-channel fallback for peripheral features; document supported device list; run early physical device tests.
- RISK: Complexity of pure-Dart Noise/crypto and secp256k1 interop.
  - Mitigation: prioritize cryptography tests early (Phase 3); if performance/interoperability issues appear, evaluate a minimal FFI for targeted primitives.
- RISK: Arti Rust integration increases binary size & cross-compile complexity.
  - Mitigation: make Tor/Arti an optional flavor; document and automate cross-compile steps and CI caching.
- RISK: BLE background constraints on iOS limit functionality.
  - Mitigation: document limitations, degrade gracefully, provide user-facing guidance; use native APIs when necessary.
- RISK: Fragmentation/MTU differences causing message corruption.
  - Mitigation: robust fragmentation protocol with checksums, retransmission, and unit tests across MTU sizes.

12. Security & Privacy Considerations
- Keys encrypted at rest; private keys never exported without user consent.
- Default telemetry off; explicit opt-in for any analytics.
- Designed for end-to-end encrypted messaging via Noise; Nostr events handled per existing NIP privacy expectations.
- Threat modeling: replay, MITM during handshake (use Noise XX with mutual static keys), device compromise mitigation via emergency wipe.

13. Testing Strategy
- Unit tests: codecs, models, crypto primitives, fragmentation logic.
- Integration tests: Noise handshakes between Flutter and Android, BLE data exchange between devices (real-device labs).
- Widget tests: onboarding, chat flows, media UI.
- End-to-end: scripted flows (on a device matrix) for onboarding → mesh join → message exchange → media transfer → verification.
- CI: run unit/widget on PRs; scheduled integration test jobs require physical device runners or an internal device farm.

14. CI / Releases
- CI: GitHub Actions with FVM-managed Flutter; matrix builds for Android and iOS/test runner; linting, unit tests, and build artifacts.
- Releases: staged rollout: internal alpha → closed beta (QA & early testers) → public beta → GA.
- Build artifacts: flavors for Tor/no-Tor to manage binary size when Arti included.

15. Rollout Plan & Monitoring
- Beta program with instrumentation capturing mesh health metrics (peer count, message success/failure rates), battery consumption, handshake failures.
- User feedback channels for connectivity/interoperability issues.
- Post-release: prioritize hotfixes for mesh/handshake regressions.

16. Team & Roles (suggested)
- Engineering Lead: architecture and integration owner.
- Mobile Engineers (Flutter): core implementation, BLE, UI.
- Native Engineers (Android): assist with BLE/peripheral behavior and interop validation.
- Crypto Engineer: Noise and primitive correctness.
- Rust/FFI Engineer: Arti integration and cross-compile CI.
- QA: test plans, device farm management.
- Product Manager: prioritization, stakeholder communication.

17. Implementation Notes & Mapping to Existing Android Codebase
- Use /Users/avillagran/Desarrollo/bitchat-android as the canonical reference for:
  - BLE UUIDs, GATT characteristics and expected behavior.
  - Binary packet header format (13 bytes) and message types to ensure protocol compatibility.
  - Noise parameter choices and identity persistence format.
  - Nostr extensions and geohash handling.
- Tasks:
  - Extract and document exact constants (UUIDs, header formats, Noise configs) from the Android repo as early artifacts (Phase 1–2) to ensure fidelity.
  - Implement serialization parity tests against Android encoders/decoders.

18. Deliverables (per phase, summary)
- Phase artifacts: skeleton repo with FVM and pubspec, models & codec library, Noise module and tests, BLE mesh core, background services, chat UI, onboarding, Nostr geohash integration, media module, verification flows, Arti FFI prototype, full test suite, and release pipeline.
- Documentation: PLAN.md updated, developer onboarding README, build scripts for Arti cross-compiles, device compatibility matrix.

19. Out-of-band Considerations
- Licensing: audit any third-party packages (cryptography, nostr libs, rust crates).
- Data migration: identify any persisted formats in Android that must be migrated for continuity (contacts/identities).
- Legal/privacy: check local regulations for background services and location usage per platform.

20. Next Steps & Acceptance to Start
- Confirm resource allocation (engineers, device access) and permission to access /Users/avillagran/Desarrollo/bitchat-android for extraction of protocol constants.
- Approve Phase 1 to begin project scaffolding and create initial PRs for the repo layout, pubspec, and CI.

Appendix A — Key Protocol & Crypto Parameters (to be validated from android repo)
- Noise protocol: Noise_XX_25519_ChaChaPoly_SHA256 (XX pattern).
- Binary header: 13-byte header (field semantics and byte layout to be copied precisely from Android).
- BLE: GATT UUID set and characteristic permissions (advertising interval, scan filters, MTU negotiation target 517).
- Nostr: NIP-01 event format; extend/adapt NIP-17 for geohash wrapping as per Android implementation.

Appendix B — Recommended pubspec dependencies (initial)
- flutter_riverpod
- flutter_blue_plus
- hive
- hive_flutter
- flutter_secure_storage
- pointycastle
- cryptography
- nostr (or equivalent)
- web_socket_channel
- freezed_annotation
- json_annotation
- go_router
- flutter_hooks
- record / audioplayers
- image_picker / file_picker
- mobile_scanner / qr_flutter
- geolocator / geocoding
- permission_handler
- flutter_local_notifications
- flutter_background_service
- http
- uuid / intl
- ffi / flutter_rust_bridge

Appendix C — Acceptance Checklist (MVP)
- [ ] Flutter app builds on Android & iOS via FVM 3.27.x
- [ ] Models & PacketCodec unit tests pass and match Android serialization
- [ ] Noise handshake interoperable with Android instance
- [ ] BLE basic mesh messaging between Flutter ↔ Android
- [ ] Chat UI and onboarding flows present on devices
- [ ] Nostr geohash channels functional vs public relays
- [ ] Media transfer (audio/image/file) works with progress and integrity checks
- [ ] Background service maintains connectivity and posts notifications (Android)
- [ ] QA signed off after closed beta tests

Contacts & Resources
- Code reference: /Users/avillagran/Desarrollo/bitchat-android (for constants & protocol)
- PLAN.md will be the living design document in the new repo and should be updated with decisions and deviations during implementation.

Approval
- Approve PRD to begin Phase 1 scaffolding and extraction of protocol constants from the Android repo (recommended immediate step).
- If approved, next deliverable: repo skeleton, FVM config, pubspec, and a short README describing developer setup (deliverable end of Week 1).