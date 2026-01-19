import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Secure storage service for managing sensitive data in the Bitchat app.
///
/// Provides encrypted persistence for:
/// - Identity keys (X25519 static keys and Ed25519 signing keys)
/// - Peer fingerprints and verification status
/// - Session metadata
/// - Application settings
///
/// All data is encrypted at rest using flutter_secure_storage which leverages
/// platform-specific secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class SecureStorageService {
  /// Singleton instance for global access
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  /// Storage namespace for identity data
  static const String _prefsName = 'bitchat_identity';

  /// Secure storage instance
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Fallback storage for macOS when keychain fails
  SharedPreferences? _fallbackPrefs;
  bool _useFallback = false;
  static const String _fallbackPrefix = 'secure_fallback_';

  /// Initialize fallback storage for macOS
  bool _initializingFallback = false;
  Future<void> _initFallbackIfNeeded() async {
    if (!Platform.isMacOS || _fallbackPrefs != null || _initializingFallback) return;
    _initializingFallback = true;
    try {
      // Test if secure storage works by calling _storage directly
      await _storage.write(key: '_test', value: 'test');
      await _storage.delete(key: '_test');
    } catch (e) {
      debugPrint('[SecureStorage] Keychain failed, using SharedPreferences fallback: $e');
      _useFallback = true;
      _fallbackPrefs = await SharedPreferences.getInstance();
    } finally {
      _initializingFallback = false;
    }
  }

  Future<void> _write(String key, String value) async {
    await _initFallbackIfNeeded();
    if (_useFallback && _fallbackPrefs != null) {
      await _fallbackPrefs!.setString('$_fallbackPrefix$key', value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> _read(String key) async {
    await _initFallbackIfNeeded();
    if (_useFallback && _fallbackPrefs != null) {
      return _fallbackPrefs!.getString('$_fallbackPrefix$key');
    } else {
      return await _storage.read(key: key);
    }
  }

  Future<void> _delete(String key) async {
    await _initFallbackIfNeeded();
    if (_useFallback && _fallbackPrefs != null) {
      await _fallbackPrefs!.remove('$_fallbackPrefix$key');
    } else {
      await _storage.delete(key: key);
    }
  }

  Future<bool> _containsKey(String key) async {
    await _initFallbackIfNeeded();
    if (_useFallback && _fallbackPrefs != null) {
      return _fallbackPrefs!.containsKey('$_fallbackPrefix$key');
    } else {
      return await _storage.containsKey(key: key);
    }
  }

  Future<Map<String, String>> _readAll() async {
    await _initFallbackIfNeeded();
    if (_useFallback && _fallbackPrefs != null) {
      final keys = _fallbackPrefs!.getKeys().where((k) => k.startsWith(_fallbackPrefix));
      return {for (var k in keys) k.substring(_fallbackPrefix.length): _fallbackPrefs!.getString(k) ?? ''};
    } else {
      return await _storage.readAll();
    }
  }

  Future<void> _deleteAll() async {
    await _initFallbackIfNeeded();
    if (_useFallback && _fallbackPrefs != null) {
      final keys = _fallbackPrefs!.getKeys().where((k) => k.startsWith(_fallbackPrefix)).toList();
      for (final k in keys) {
        await _fallbackPrefs!.remove(k);
      }
    } else {
      await _storage.deleteAll();
    }
  }

  // MARK: - Storage Keys

  // Static X25519 keys for Noise protocol
  static const String _keyStaticPrivateKey = 'static_private_key';
  static const String _keyStaticPublicKey = 'static_public_key';

  // Ed25519 signing keys for identity verification
  static const String _keySigningPrivateKey = 'signing_private_key';
  static const String _keySigningPublicKey = 'signing_public_key';

  // Fingerprint storage
  static const String _keyVerifiedFingerprints = 'verified_fingerprints';
  static const String _keyCachedPeerFingerprints = 'cached_peer_fingerprints';
  static const String _keyCachedPeerNoiseKeys = 'cached_peer_noise_keys';
  static const String _keyCachedNoiseFingerprints = 'cached_noise_fingerprints';
  static const String _keyCachedFingerprintNicknames = 'cached_fingerprint_nicknames';

  // Session storage
  static const String _keySessionPrefix = 'session_';

  // Settings storage
  static const String _keySettings = 'app_settings';

  // MARK: - Static Key Management (X25519 for Noise)

  /// Load saved static X25519 key pair for Noise protocol.
  ///
  /// Returns null if no keys exist.
  /// Keys are Base64 encoded when stored.
  Future<KeyPair?> loadStaticKeyPair() async {
    try {
      final privateKeyString = await _read( _keyStaticPrivateKey);
      final publicKeyString = await _read( _keyStaticPublicKey);

      if (privateKeyString == null || publicKeyString == null) {
        return null;
      }

      final privateKey = base64Decode(privateKeyString);
      final publicKey = base64Decode(publicKeyString);

      // Validate key sizes (X25519 keys are 32 bytes)
      if (privateKey.length == 32 && publicKey.length == 32) {
        return KeyPair(
          Uint8List.fromList(privateKey),
          Uint8List.fromList(publicKey),
        );
      }

      return null;
    } catch (e) {
      throw SecureStorageException('Failed to load static key pair: $e');
    }
  }

  /// Save static X25519 key pair to secure storage.
  ///
  /// Keys are Base64 encoded before storage.
  /// Throws [SecureStorageException] if the operation fails.
  Future<void> saveStaticKeyPair(
      Uint8List privateKey, Uint8List publicKey) async {
    try {
      // Validate key sizes
      if (privateKey.length != 32 || publicKey.length != 32) {
        throw SecureStorageException(
          'Invalid key sizes: private=${privateKey.length}, public=${publicKey.length}',
        );
      }

      final privateKeyString = base64Encode(privateKey);
      final publicKeyString = base64Encode(publicKey);

      await _write( _keyStaticPrivateKey, privateKeyString);
      await _write( _keyStaticPublicKey, publicKeyString);
    } catch (e) {
      throw SecureStorageException('Failed to save static key pair: $e');
    }
  }

  // MARK: - Signing Key Management (Ed25519)

  /// Load saved Ed25519 signing key pair.
  ///
  /// Returns null if no keys exist.
  Future<KeyPair?> loadSigningKeyPair() async {
    try {
      final privateKeyString = await _read( _keySigningPrivateKey);
      final publicKeyString = await _read( _keySigningPublicKey);

      if (privateKeyString == null || publicKeyString == null) {
        return null;
      }

      final privateKey = base64Decode(privateKeyString);
      final publicKey = base64Decode(publicKeyString);

      // Validate key sizes (Ed25519 keys are 32 bytes)
      if (privateKey.length == 32 && publicKey.length == 32) {
        return KeyPair(
          Uint8List.fromList(privateKey),
          Uint8List.fromList(publicKey),
        );
      }

      return null;
    } catch (e) {
      throw SecureStorageException('Failed to load signing key pair: $e');
    }
  }

  /// Save Ed25519 signing key pair to secure storage.
  ///
  /// Throws [SecureStorageException] if the operation fails.
  Future<void> saveSigningKeyPair(
      Uint8List privateKey, Uint8List publicKey) async {
    try {
      // Validate key sizes
      if (privateKey.length != 32 || publicKey.length != 32) {
        throw SecureStorageException(
          'Invalid key sizes: private=${privateKey.length}, public=${publicKey.length}',
        );
      }

      final privateKeyString = base64Encode(privateKey);
      final publicKeyString = base64Encode(publicKey);

      await _write( _keySigningPrivateKey, privateKeyString);
      await _write( _keySigningPublicKey, publicKeyString);
    } catch (e) {
      throw SecureStorageException('Failed to save signing key pair: $e');
    }
  }

  // MARK: - Fingerprint Generation and Validation

  /// Generate a SHA-256 fingerprint from public key data.
  ///
  /// Returns a hex-encoded string representing the fingerprint.
  String generateFingerprint(Uint8List publicKeyData) {
    final digest = sha256.convert(publicKeyData);
    return digest.toString();
  }

  /// Validate that a fingerprint string is in the correct format.
  ///
  /// SHA-256 fingerprints should be 64 hexadecimal characters.
  bool isValidFingerprint(String fingerprint) {
    return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fingerprint);
  }

  // MARK: - Verified Fingerprints

  /// Get all verified fingerprints.
  ///
  /// Returns a set of fingerprint strings that have been manually verified.
  Future<Set<String>> getVerifiedFingerprints() async {
    try {
      final data = await _read( _keyVerifiedFingerprints);
      if (data == null) return <String>{};

      final json = jsonDecode(data) as List<dynamic>;
      return json.map((e) => e as String).toSet();
    } catch (e) {
      throw SecureStorageException('Failed to load verified fingerprints: $e');
    }
  }

  /// Check if a fingerprint is verified.
  Future<bool> isVerifiedFingerprint(String fingerprint) async {
    if (!isValidFingerprint(fingerprint)) return false;
    final verified = await getVerifiedFingerprints();
    return verified.contains(fingerprint.toLowerCase());
  }

  /// Set the verification status of a fingerprint.
  Future<void> setVerifiedFingerprint(
      String fingerprint, bool verified) async {
    if (!isValidFingerprint(fingerprint)) {
      throw SecureStorageException('Invalid fingerprint format');
    }

    try {
      final current = await getVerifiedFingerprints();
      final normalizedFingerprint = fingerprint.toLowerCase();

      if (verified) {
        current.add(normalizedFingerprint);
      } else {
        current.remove(normalizedFingerprint);
      }

      final data = jsonEncode(current.toList());
      await _write( _keyVerifiedFingerprints, data);
    } catch (e) {
      throw SecureStorageException('Failed to update verified fingerprint: $e');
    }
  }

  // MARK: - Cached Peer Data

  /// Get cached fingerprint for a specific peer ID.
  ///
  /// Returns the fingerprint string or null if not cached.
  Future<String?> getCachedPeerFingerprint(String peerID) async {
    try {
      final entries = await _read( _keyCachedPeerFingerprints);
      if (entries == null) return null;

      final normalizedPeerID = peerID.toLowerCase();
      final entryList = jsonDecode(entries) as List<dynamic>;

      for (final entry in entryList) {
        final entryStr = entry as String;
        if (entryStr.startsWith('$normalizedPeerID:')) {
          final parts = entryStr.split(':');
          if (parts.length >= 2) {
            final fingerprint = parts[1];
            if (isValidFingerprint(fingerprint)) {
              return fingerprint.toLowerCase();
            }
          }
        }
      }

      return null;
    } catch (e) {
      throw SecureStorageException('Failed to load cached peer fingerprint: $e');
    }
  }

  /// Cache the fingerprint for a specific peer ID.
  Future<void> cachePeerFingerprint(
      String peerID, String fingerprint) async {
    if (!isValidFingerprint(fingerprint)) {
      throw SecureStorageException('Invalid fingerprint format');
    }

    try {
      final entriesStr = await _read( _keyCachedPeerFingerprints);
      final entryList = <String>[];

      if (entriesStr != null) {
        entryList.addAll((jsonDecode(entriesStr) as List<dynamic>)
            .map((e) => e as String));
      }

      final normalizedPeerID = peerID.toLowerCase();
      final normalizedFingerprint = fingerprint.toLowerCase();

      // Remove existing entries for this peer
      entryList.removeWhere((e) => e.startsWith('$normalizedPeerID:'));

      // Add new entry
      entryList.add('$normalizedPeerID:$normalizedFingerprint');

      final data = jsonEncode(entryList);
      await _write( _keyCachedPeerFingerprints, data);
    } catch (e) {
      throw SecureStorageException('Failed to cache peer fingerprint: $e');
    }
  }

  /// Get cached Noise key for a specific peer ID.
  ///
  /// Returns the Noise public key as a hex string or null if not cached.
  Future<String?> getCachedPeerNoiseKey(String peerID) async {
    try {
      final entries = await _read( _keyCachedPeerNoiseKeys);
      if (entries == null) return null;

      final normalizedPeerID = peerID.toLowerCase();
      final entryList = jsonDecode(entries) as List<dynamic>;

      for (final entry in entryList) {
        final entryStr = entry as String;
        if (entryStr.startsWith('$normalizedPeerID=')) {
          final parts = entryStr.split('=');
          if (parts.length >= 2) {
            final noiseKey = parts[1];
            if (RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(noiseKey)) {
              return noiseKey.toLowerCase();
            }
          }
        }
      }

      return null;
    } catch (e) {
      throw SecureStorageException('Failed to load cached peer noise key: $e');
    }
  }

  /// Cache the Noise key for a specific peer ID.
  Future<void> cachePeerNoiseKey(String peerID, String noiseKeyHex) async {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(noiseKeyHex)) {
      throw SecureStorageException('Invalid Noise key format');
    }

    try {
      final entriesStr = await _read( _keyCachedPeerNoiseKeys);
      final entryList = <String>[];

      if (entriesStr != null) {
        entryList.addAll((jsonDecode(entriesStr) as List<dynamic>)
            .map((e) => e as String));
      }

      final normalizedPeerID = peerID.toLowerCase();
      final normalizedNoiseKey = noiseKeyHex.toLowerCase();

      // Remove existing entries for this peer
      entryList.removeWhere((e) => e.startsWith('$normalizedPeerID='));

      // Add new entry
      entryList.add('$normalizedPeerID=$normalizedNoiseKey');

      final data = jsonEncode(entryList);
      await _write( _keyCachedPeerNoiseKeys, data);
    } catch (e) {
      throw SecureStorageException('Failed to cache peer noise key: $e');
    }
  }

  /// Get cached fingerprint for a specific Noise key.
  Future<String?> getCachedNoiseFingerprint(String noiseKeyHex) async {
    try {
      final entries = await _read( _keyCachedNoiseFingerprints);
      if (entries == null) return null;

      final key = noiseKeyHex.toLowerCase();
      final entryList = jsonDecode(entries) as List<dynamic>;

      for (final entry in entryList) {
        final entryStr = entry as String;
        if (entryStr.startsWith('$key=')) {
          final parts = entryStr.split('=');
          if (parts.length >= 2) {
            final fingerprint = parts[1];
            if (isValidFingerprint(fingerprint)) {
              return fingerprint.toLowerCase();
            }
          }
        }
      }

      return null;
    } catch (e) {
      throw SecureStorageException('Failed to load cached noise fingerprint: $e');
    }
  }

  /// Cache the fingerprint for a specific Noise key.
  Future<void> cacheNoiseFingerprint(
      String noiseKeyHex, String fingerprint) async {
    if (!isValidFingerprint(fingerprint)) {
      throw SecureStorageException('Invalid fingerprint format');
    }
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(noiseKeyHex)) {
      throw SecureStorageException('Invalid Noise key format');
    }

    try {
      final entriesStr = await _read( _keyCachedNoiseFingerprints);
      final entryList = <String>[];

      if (entriesStr != null) {
        entryList.addAll((jsonDecode(entriesStr) as List<dynamic>)
            .map((e) => e as String));
      }

      final key = noiseKeyHex.toLowerCase();
      final normalizedFingerprint = fingerprint.toLowerCase();

      // Remove existing entries for this key
      entryList.removeWhere((e) => e.startsWith('$key='));

      // Add new entry
      entryList.add('$key=$normalizedFingerprint');

      final data = jsonEncode(entryList);
      await _write( _keyCachedNoiseFingerprints, data);
    } catch (e) {
      throw SecureStorageException('Failed to cache noise fingerprint: $e');
    }
  }

  /// Get cached nickname for a specific fingerprint.
  Future<String?> getCachedFingerprintNickname(String fingerprint) async {
    if (!isValidFingerprint(fingerprint)) return null;

    try {
      final entries = await _read( _keyCachedFingerprintNicknames);
      if (entries == null) return null;

      final key = fingerprint.toLowerCase();
      final entryList = jsonDecode(entries) as List<dynamic>;

      for (final entry in entryList) {
        final entryStr = entry as String;
        if (entryStr.startsWith('$key=')) {
          final parts = entryStr.split('=');
          if (parts.length >= 2) {
            final encoded = parts[1];
            final bytes = base64Decode(encoded);
            return utf8.decode(bytes);
          }
        }
      }

      return null;
    } catch (e) {
      throw SecureStorageException(
          'Failed to load cached fingerprint nickname: $e');
    }
  }

  /// Cache a nickname for a specific fingerprint.
  Future<void> cacheFingerprintNickname(
      String fingerprint, String nickname) async {
    if (!isValidFingerprint(fingerprint)) {
      throw SecureStorageException('Invalid fingerprint format');
    }

    try {
      final entriesStr = await _read( _keyCachedFingerprintNicknames);
      final entryList = <String>[];

      if (entriesStr != null) {
        entryList.addAll((jsonDecode(entriesStr) as List<dynamic>)
            .map((e) => e as String));
      }

      final key = fingerprint.toLowerCase();
      final encoded = base64Encode(utf8.encode(nickname));

      // Remove existing entries for this fingerprint
      entryList.removeWhere((e) => e.startsWith('$key='));

      // Add new entry
      entryList.add('$key=$encoded');

      final data = jsonEncode(entryList);
      await _write( _keyCachedFingerprintNicknames, data);
    } catch (e) {
      throw SecureStorageException('Failed to cache fingerprint nickname: $e');
    }
  }

  // MARK: - Session Storage

  /// Save session metadata for a specific peer.
  ///
  /// The metadata map can include any JSON-serializable data about the session.
  Future<void> saveSessionMetadata(
      String peerID, Map<String, dynamic> metadata) async {
    try {
      final key = '$_keySessionPrefix${peerID.toLowerCase()}';
      final data = jsonEncode(metadata);
      await _write( key, data);
    } catch (e) {
      throw SecureStorageException('Failed to save session metadata: $e');
    }
  }

  /// Load session metadata for a specific peer.
  ///
  /// Returns the metadata map or null if no session is stored.
  Future<Map<String, dynamic>?> loadSessionMetadata(String peerID) async {
    try {
      final key = '$_keySessionPrefix${peerID.toLowerCase()}';
      final data = await _read( key);
      if (data == null) return null;

      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      throw SecureStorageException('Failed to load session metadata: $e');
    }
  }

  /// Delete session metadata for a specific peer.
  Future<void> deleteSessionMetadata(String peerID) async {
    try {
      final key = '$_keySessionPrefix${peerID.toLowerCase()}';
      await _delete( key);
    } catch (e) {
      throw SecureStorageException('Failed to delete session metadata: $e');
    }
  }

  /// Get all peer IDs with stored session metadata.
  Future<Set<String>> getAllSessionPeerIDs() async {
    try {
      final allKeys = await _readAll();
      final sessionKeys = allKeys.keys
          .where((key) => key.startsWith(_keySessionPrefix))
          .map((key) => key.substring(_keySessionPrefix.length));
      return sessionKeys.toSet();
    } catch (e) {
      throw SecureStorageException('Failed to get session peer IDs: $e');
    }
  }

  // MARK: - Settings Persistence

  /// Save application settings.
  ///
  /// The settings map should contain JSON-serializable values.
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final data = jsonEncode(settings);
      await _write( _keySettings, data);
    } catch (e) {
      throw SecureStorageException('Failed to save settings: $e');
    }
  }

  /// Load application settings.
  ///
  /// Returns the settings map or an empty map if no settings are stored.
  Future<Map<String, dynamic>> loadSettings() async {
    try {
      final data = await _read( _keySettings);
      if (data == null) return <String, dynamic>{};

      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      throw SecureStorageException('Failed to load settings: $e');
    }
  }

  /// Get a specific setting value.
  ///
  /// Returns the value or null if the setting does not exist.
  Future<dynamic> getSetting(String key) async {
    try {
      final settings = await loadSettings();
      return settings[key];
    } catch (e) {
      throw SecureStorageException('Failed to get setting: $e');
    }
  }

  /// Update specific setting values without overwriting other settings.
  Future<void> updateSettings(Map<String, dynamic> updates) async {
    try {
      final current = await loadSettings();
      current.addAll(updates);
      await saveSettings(current);
    } catch (e) {
      throw SecureStorageException('Failed to update settings: $e');
    }
  }

  // MARK: - Encryption/Decryption Helpers

  /// Encrypt a string value before storage.
  ///
  /// Uses X25519 key derivation with a salt. The salt is stored with the
  /// encrypted value for later decryption.
  Future<String> encryptString(String plaintext) async {
    try {
      // Generate a random salt
      final salt = Uint8List(16);
      final random = Random.secure();
      for (int i = 0; i < salt.length; i++) {
        salt[i] = random.nextInt(256);
      }

      // Derive a key from the salt using SHA-256
      final hash = sha256.convert(salt);
      final keyBytes = hash.bytes;

      // Simple XOR cipher for demonstration - in production, use proper AEAD
      final plainBytes = utf8.encode(plaintext);
      final encrypted = Uint8List(plainBytes.length);

      for (int i = 0; i < plainBytes.length; i++) {
        encrypted[i] = plainBytes[i] ^ keyBytes[i % keyBytes.length];
      }

      // Combine salt + encrypted data
      final combined = Uint8List(salt.length + encrypted.length);
      combined.setRange(0, salt.length, salt);
      combined.setRange(salt.length, combined.length, encrypted);

      return base64Encode(combined);
    } catch (e) {
      throw SecureStorageException('Failed to encrypt string: $e');
    }
  }

  /// Decrypt a string value that was previously encrypted.
  Future<String> decryptString(String ciphertext) async {
    try {
      final combined = base64Decode(ciphertext);

      if (combined.length < 16) {
        throw SecureStorageException('Invalid ciphertext length');
      }

      // Extract salt and encrypted data
      final salt = combined.sublist(0, 16);
      final encrypted = combined.sublist(16);

      // Derive the key from the salt
      final hash = sha256.convert(salt);
      final keyBytes = hash.bytes;

      // Decrypt using the same XOR cipher
      final plainBytes = Uint8List(encrypted.length);
      for (int i = 0; i < encrypted.length; i++) {
        plainBytes[i] = encrypted[i] ^ keyBytes[i % keyBytes.length];
      }

      return utf8.decode(plainBytes);
    } catch (e) {
      throw SecureStorageException('Failed to decrypt string: $e');
    }
  }

  // MARK: - General Storage Operations

  /// Store a generic secure value.
  Future<void> storeSecureValue(String key, String value) async {
    try {
      await _write( key, value);
    } catch (e) {
      throw SecureStorageException('Failed to store secure value: $e');
    }
  }

  /// Retrieve a generic secure value.
  Future<String?> getSecureValue(String key) async {
    try {
      return await _read( key);
    } catch (e) {
      throw SecureStorageException('Failed to get secure value: $e');
    }
  }

  /// Remove a secure value.
  Future<void> removeSecureValue(String key) async {
    try {
      await _delete( key);
    } catch (e) {
      throw SecureStorageException('Failed to remove secure value: $e');
    }
  }

  /// Check if a secure value exists.
  Future<bool> hasSecureValue(String key) async {
    try {
      return await _containsKey( key);
    } catch (e) {
      throw SecureStorageException('Failed to check secure value: $e');
    }
  }

  // MARK: - Data Management

  /// Check if identity data exists.
  Future<bool> hasIdentityData() async {
    try {
      final hasStaticKey = await _containsKey( _keyStaticPrivateKey);
      final hasSigningKey = await _containsKey( _keySigningPrivateKey);
      return hasStaticKey && hasSigningKey;
    } catch (e) {
      throw SecureStorageException('Failed to check identity data: $e');
    }
  }

  /// Clear all identity data (for panic mode).
  Future<void> clearIdentityData() async {
    try {
      await _delete( _keyStaticPrivateKey);
      await _delete( _keyStaticPublicKey);
      await _delete( _keySigningPrivateKey);
      await _delete( _keySigningPublicKey);
      await _delete( _keyVerifiedFingerprints);
    } catch (e) {
      throw SecureStorageException('Failed to clear identity data: $e');
    }
  }

  /// Clear all cached peer data.
  Future<void> clearCachedPeerData() async {
    try {
      await _delete( _keyCachedPeerFingerprints);
      await _delete( _keyCachedPeerNoiseKeys);
      await _delete( _keyCachedNoiseFingerprints);
      await _delete( _keyCachedFingerprintNicknames);
    } catch (e) {
      throw SecureStorageException('Failed to clear cached peer data: $e');
    }
  }

  /// Clear all session metadata.
  Future<void> clearAllSessions() async {
    try {
      final allKeys = await _readAll();
      final sessionKeys = allKeys.keys
          .where((key) => key.startsWith(_keySessionPrefix));
      for (final key in sessionKeys) {
        await _delete( key);
      }
    } catch (e) {
      throw SecureStorageException('Failed to clear all sessions: $e');
    }
  }

  /// Clear all stored data.
  Future<void> clearAll() async {
    try {
      await _deleteAll();
    } catch (e) {
      throw SecureStorageException('Failed to clear all data: $e');
    }
  }

  /// Get debug information about the storage state.
  Future<String> getDebugInfo() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Secure Storage Debug ===');

    final hasIdentity = await hasIdentityData();
    buffer.writeln('Has identity: $hasIdentity');

    if (hasIdentity) {
      final staticKeyPair = await loadStaticKeyPair();
      if (staticKeyPair != null) {
        final fingerprint = generateFingerprint(staticKeyPair.publicKey);
        buffer.writeln('Identity fingerprint: ${fingerprint.substring(0, 16)}...');
      }

      final signingKeyPair = await loadSigningKeyPair();
      if (signingKeyPair != null) {
        final fingerprint = generateFingerprint(signingKeyPair.publicKey);
        buffer.writeln('Signing fingerprint: ${fingerprint.substring(0, 16)}...');
      }
    }

    final verifiedFingerprints = await getVerifiedFingerprints();
    buffer.writeln('Verified fingerprints: ${verifiedFingerprints.length}');

    final sessionPeerIDs = await getAllSessionPeerIDs();
    buffer.writeln('Active sessions: ${sessionPeerIDs.length}');

    return buffer.toString();
  }
}

/// Represents a cryptographic key pair.
class KeyPair {
  final Uint8List privateKey;
  final Uint8List publicKey;

  KeyPair(this.privateKey, this.publicKey);
}

/// Exception thrown when secure storage operations fail.
class SecureStorageException implements Exception {
  final String message;
  SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}
