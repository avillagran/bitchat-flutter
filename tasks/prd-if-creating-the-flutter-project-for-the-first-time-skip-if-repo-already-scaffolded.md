Appendix D — FVM / Bootstrap Commands (literal block to include in developer docs)
- Notes: Run these from your dev machine. Only run `fvm flutter create .` if the target directory is empty or you intend to scaffold a new project.

Commands:
dart pub global activate fvm
cd /Users/avillagran/Desarrollo/bitchat-flutter
fvm install 3.27.4
fvm use 3.27.4
# If creating the Flutter project for the first time (skip if repo already scaffolded)
fvm flutter create . --org com.bitchat --project-name bitchat
fvm flutter pub get
fvm flutter doctor --verbose
# Run on device/emulator for a smoke check
fvm flutter run --release

Appendix E — Extraction Tasks and Raw-Constants Guidance (actions, search patterns, and output artifact)
Purpose: extract exact protocol constants and platform settings from /Users/avillagran/Desarrollo/bitchat-android so the Flutter implementation is byte-for-byte compatible.

E.1 — Deliverable
- A single JSON file placed in the new repo at docs/protocol_constants.json containing the canonical values:
  - ble: { service_uuid, characteristic_read_uuid, characteristic_write_uuid, advertising_payload_format, advertised_service_name(if any) }
  - protocol: { header_length, header_field_definitions (name/offset/length/endianness), type_enum_values, max_payload_size, fragment_header_layout }
  - noise: { pattern_string (e.g., "Noise_XX_25519_ChaChaPoly_SHA256"), DH_alg, cipher, hash, any pre-shared/static-key usage flags }
  - nostr: { key_scheme (secp256k1/ed25519), NIP extensions used (NIP-17 adaptation details), relay defaults }
  - storage: { identity_file_paths, db_names, keywrap/keystore formats, encryption flags }
  - android: { required_permissions strings, manifest intent-filters, service/component names, build flavors }
  - sample_values: small example values to sanity-check (one sample UUID, one sample header hex string)

E.2 — Extraction checklist (manual + grep/ripgrep patterns)
- Search for BLE UUIDs and GATT characteristic names:
  - rg -n --hidden -S "UUID|service_uuid|CHARACTERISTIC|Gatt" /Users/avillagran/Desarrollo/bitchat-android
  - rg -n --hidden -S "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" /Users/avillagran/Desarrollo/bitchat-android
- Find the binary header and packet codec:
  - rg -n --hidden -S "HEADER_SIZE|HEADER_LEN|PACKET_HEADER|byte\\[13\\]|13\\s*\\*\\s*bytes|header_length" /Users/avillagran/Desarrollo/bitchat-android
  - rg -n --hidden -S "PacketCodec|PacketParser|BinaryProtocol|serialize\\(|deserialize\\(|toBytes\\(|fromBytes\\(" /Users/avillagran/Desarrollo/bitchat-android
- Locate fragmentation and MTU logic:
  - rg -n --hidden -S "fragment|fragmentation|MTU|maxPacketSize|reassembly|reassemble" /Users/avillagran/Desarrollo/bitchat-android
- Locate Noise / crypto parameters:
  - rg -n --hidden -S "Noise_|NoiseXX|Noise_XX|ChaCha|ChaCha20|Poly1305|25519|ed25519|secp256k1|Schnorr" /Users/avillagran/Desarrollo/bitchat-android
- Locate Nostr and NIP-17 usages:
  - rg -n --hidden -S "NIP-17|NIP17|Nostr|RelayManager|nostr" /Users/avillagran/Desarrollo/bitchat-android
- Identity and storage:
  - rg -n --hidden -S "identity|privateKey|keystore|shared_prefs|Hive|database|encrypted" /Users/avillagran/Desarrollo/bitchat-android
- Android manifest, permissions, and services:
  - rg -n --hidden -S "AndroidManifest.xml|uses-permission|SERVICE_NAME|foregroundServiceType|REQUEST_ENABLE_BT" /Users/avillagran/Desarrollo/bitchat-android
- Tor/Arti hints:
  - rg -n --hidden -S "arti|tor|rust|jni|ffi|libart|flutter_rust_bridge" /Users/avillagran/Desarrollo/bitchat-android
- Helpful exact regex for UUID extraction:
  - rg -o --hidden -n "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" /Users/avillagran/Desarrollo/bitchat-android | sort -u

E.3 — How to interpret header/field semantics (what to capture)
- For each header field capture:
  - name, byte_offset (0-based), length_in_bytes, signed/unsigned, endianness, meaning (e.g., version, type, flags, seq, src_id, dst_id), valid value set or enum mapping.
- For enums/constants capture:
  - constant_name, integer_value (hex/dec), source_file_path, line_number.
- For BLE advertising payload capture:
  - exact advertising bytes or structured key-value (flags, local name, service UUID list, manufacturer data) and any encoding (little/big-endian) used.

E.4 — Suggested extraction process and responsibilities
- Step 1 (Engineer, Phase 1): Run the ripgrep commands above to create a raw findings file (raw_findings.txt).
- Step 2 (Engineer + Crypto lead): Manually inspect candidate files (likely under src/main/java or src/main/kotlin) and verify header layout and Noise params.
- Step 3 (Engineer): Populate docs/protocol_constants.json with canonical values and add unit tests in the Flutter repo that assert parity against these constants (e.g., expected header length === 13).
- Step 4 (QA): Create interop test harness that sends a small known packet from Android → Flutter and verifies correct parsing (add to Phase 2 acceptance).
- Responsibility notes: Native Android engineer should confirm ambiguous values (e.g., endianness), and cryptography engineer should validate Noise parameter usage.

E.5 — Example JSON snippet (what to produce after extraction)
{
  "ble": {
    "service_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "char_read_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "char_write_uuid": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "advertising_format_notes": "manufacturer data contains protocol version at offset 2"
  },
  "protocol": {
    "header_length": 13,
    "fields": [
      {"name":"version","offset":0,"length":1,"endianness":"big","notes":"protocol version"},
      {"name":"type","offset":1,"length":1,"notes":"message type enum"},
      {"name":"flags","offset":2,"length":1,"notes":"bitflags"},
      {"name":"seq","offset":3,"length":4,"endianness":"big","notes":"sequence number"},
      {"name":"src_id","offset":7,"length":3,"notes":"3-byte sender id"},
      {"name":"dst_id","offset":10,"length":3,"notes":"3-byte destination id"}
    ]
  },
  "noise": {"pattern":"Noise_XX_25519_ChaChaPoly_SHA256"},
  "nostr": {"nip_extensions":["NIP-17-adapted"]},
  "storage": {"identity_path":"data/user/0/.../files/identity.bin"}
}

E.6 — Verification tests to add in Flutter repo once constants.json exists
- Unit test: assert(protocol_constants.header_length == 13)
- Serialization test: round-trip a canonical packet hex string extracted from Android
- BLE smoke test: attempt to connect to an Android device advertising the canonical service UUID and read the advertised payload; assert format matches docs/protocol_constants.json

E.7 — Safety & provenance
- When copying any constants or code snippets from the Android repo, add a source reference comment in docs/protocol_constants.json with file path and commit/last-modified timestamp.
- Keep any sensitive keys out of repo; only capture constants and public sample values.

E.8 — Follow-up artifacts to commit to the new repo
- docs/protocol_constants.json (canonical values + source references)
- docs/extraction_raw_findings.txt (raw ripgrep output)
- test/interop/android_sample_packets/ (small fixtures used by unit tests)
- a short README docs/EXTRACTION.md describing how the values were obtained and how to re-run the extraction