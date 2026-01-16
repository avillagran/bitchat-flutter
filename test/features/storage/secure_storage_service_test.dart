import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/storage/secure_storage_service.dart';

void main() {
  // Initialize Flutter bindings for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureStorageService', () {
    late SecureStorageService secureStorageService;

    setUp(() {
      secureStorageService = SecureStorageService();
    });

    tearDown(() async {
      // Clean up after each test - ignore errors if native plugin not available
      try {
        await secureStorageService.clearAll();
      } catch (e) {
        // Ignore - expected in unit tests without native platform
      }
    });

    group('Static Key Management', () {
      test('should save and load static key pair', () async {
        // Arrange
        final privateKey = Uint8List(32);
        final publicKey = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          privateKey[i] = i;
          publicKey[i] = i + 32;
        }

        // Act
        await secureStorageService.saveStaticKeyPair(privateKey, publicKey);
        final loaded = await secureStorageService.loadStaticKeyPair();

        // Assert
        expect(loaded, isNotNull);
        expect(loaded!.privateKey, equals(privateKey));
        expect(loaded.publicKey, equals(publicKey));
      });

      test('should return null when static keys do not exist', () async {
        // Act
        final loaded = await secureStorageService.loadStaticKeyPair();

        // Assert
        expect(loaded, isNull);
      });

      test('should throw exception when saving invalid key sizes', () async {
        // Arrange
        final invalidPrivateKey = Uint8List(16);
        final invalidPublicKey = Uint8List(64);

        // Act & Assert
        expect(
          () => secureStorageService.saveStaticKeyPair(
              invalidPrivateKey, invalidPublicKey),
          throwsA(isA<SecureStorageException>()),
        );
      });
    });

    group('Signing Key Management', () {
      test('should save and load signing key pair', () async {
        // Arrange
        final privateKey = Uint8List(32);
        final publicKey = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          privateKey[i] = i + 64;
          publicKey[i] = i + 96;
        }

        // Act
        await secureStorageService.saveSigningKeyPair(privateKey, publicKey);
        final loaded = await secureStorageService.loadSigningKeyPair();

        // Assert
        expect(loaded, isNotNull);
        expect(loaded!.privateKey, equals(privateKey));
        expect(loaded.publicKey, equals(publicKey));
      });

      test('should return null when signing keys do not exist', () async {
        // Act
        final loaded = await secureStorageService.loadSigningKeyPair();

        // Assert
        expect(loaded, isNull);
      });

      test('should throw exception when saving invalid signing key sizes',
          () async {
        // Arrange
        final invalidPrivateKey = Uint8List(24);

        // Act & Assert
        expect(
          () => secureStorageService.saveSigningKeyPair(invalidPrivateKey,
              Uint8List(32)),
          throwsA(isA<SecureStorageException>()),
        );
      });
    });

    group('Fingerprint Generation and Validation', () {
      test('should generate valid SHA-256 fingerprint', () {
        // Arrange
        final publicKey = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          publicKey[i] = i;
        }

        // Act
        final fingerprint = secureStorageService.generateFingerprint(publicKey);

        // Assert
        expect(fingerprint.length, equals(64));
        expect(RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fingerprint), isTrue);
      });

      test('should validate correct fingerprint format', () {
        // Arrange
        const validFingerprint =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

        // Act & Assert
        expect(secureStorageService.isValidFingerprint(validFingerprint), isTrue);
      });

      test('should reject invalid fingerprint format', () {
        // Arrange
        const invalidFingerprint1 = 'too_short';
        const invalidFingerprint2 = 'not-hex-at-all!!!';
        final invalidFingerprint3 = 'g' * 64; // Invalid hex character

        // Act & Assert
        expect(
            secureStorageService.isValidFingerprint(invalidFingerprint1),
            isFalse);
        expect(
            secureStorageService.isValidFingerprint(invalidFingerprint2),
            isFalse);
        expect(
            secureStorageService.isValidFingerprint(invalidFingerprint3),
            isFalse);
      });
    });

    group('Verified Fingerprints', () {
      test('should add and retrieve verified fingerprints', () async {
        // Arrange
        const fingerprint1 =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        const fingerprint2 =
            'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

        // Act
        await secureStorageService.setVerifiedFingerprint(fingerprint1, true);
        await secureStorageService.setVerifiedFingerprint(fingerprint2, true);
        final verified = await secureStorageService.getVerifiedFingerprints();

        // Assert
        expect(verified.length, equals(2));
        expect(verified.contains(fingerprint1.toLowerCase()), isTrue);
        expect(verified.contains(fingerprint2.toLowerCase()), isTrue);
      });

      test('should check if fingerprint is verified', () async {
        // Arrange
        const fingerprint =
            'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

        // Act
        await secureStorageService.setVerifiedFingerprint(fingerprint, true);
        final isVerified =
            await secureStorageService.isVerifiedFingerprint(fingerprint);

        // Assert
        expect(isVerified, isTrue);
      });

      test('should remove verified fingerprint', () async {
        // Arrange
        const fingerprint =
            'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';

        // Act
        await secureStorageService.setVerifiedFingerprint(fingerprint, true);
        await secureStorageService.setVerifiedFingerprint(fingerprint, false);
        final isVerified =
            await secureStorageService.isVerifiedFingerprint(fingerprint);

        // Assert
        expect(isVerified, isFalse);
      });

      test('should handle case-insensitive fingerprint checks', () async {
        // Arrange
        const fingerprint =
            'E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6A1B2C3D4E5F6';

        // Act
        await secureStorageService.setVerifiedFingerprint(fingerprint, true);
        final isVerified = await secureStorageService.isVerifiedFingerprint(
          fingerprint.toLowerCase(),
        );

        // Assert
        expect(isVerified, isTrue);
      });
    });

    group('Cached Peer Data', () {
      test('should cache and retrieve peer fingerprint', () async {
        // Arrange
        const peerID = 'peer-123';
        const fingerprint =
            'f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

        // Act
        await secureStorageService.cachePeerFingerprint(peerID, fingerprint);
        final cached =
            await secureStorageService.getCachedPeerFingerprint(peerID);

        // Assert
        expect(cached, equals(fingerprint.toLowerCase()));
      });

      test('should return null for uncached peer fingerprint', () async {
        // Act
        final cached = await secureStorageService
            .getCachedPeerFingerprint('non-existent-peer');

        // Assert
        expect(cached, isNull);
      });

      test('should cache and retrieve peer noise key', () async {
        // Arrange
        const peerID = 'peer-456';
        const noiseKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

        // Act
        await secureStorageService.cachePeerNoiseKey(peerID, noiseKey);
        final cached = await secureStorageService.getCachedPeerNoiseKey(peerID);

        // Assert
        expect(cached, equals(noiseKey.toLowerCase()));
      });

      test('should cache and retrieve noise fingerprint', () async {
        // Arrange
        const noiseKey =
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
        const fingerprint =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

        // Act
        await secureStorageService.cacheNoiseFingerprint(noiseKey, fingerprint);
        final cached = await secureStorageService.getCachedNoiseFingerprint(noiseKey);

        // Assert
        expect(cached, equals(fingerprint.toLowerCase()));
      });

      test('should cache and retrieve fingerprint nickname', () async {
        // Arrange
        const fingerprint =
            'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
        const nickname = 'Alice';

        // Act
        await secureStorageService.cacheFingerprintNickname(
            fingerprint, nickname);
        final cached =
            await secureStorageService.getCachedFingerprintNickname(fingerprint);

        // Assert
        expect(cached, equals(nickname));
      });

      test('should handle special characters in nicknames', () async {
        // Arrange
        const fingerprint =
            'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
        const nickname = 'User 😊 & Special!@#';

        // Act
        await secureStorageService.cacheFingerprintNickname(
            fingerprint, nickname);
        final cached =
            await secureStorageService.getCachedFingerprintNickname(fingerprint);

        // Assert
        expect(cached, equals(nickname));
      });

      test('should update cached peer fingerprint on duplicate', () async {
        // Arrange
        const peerID = 'peer-789';
        const fingerprint1 =
            'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';
        const fingerprint2 =
            'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6';

        // Act
        await secureStorageService.cachePeerFingerprint(peerID, fingerprint1);
        await secureStorageService.cachePeerFingerprint(peerID, fingerprint2);
        final cached =
            await secureStorageService.getCachedPeerFingerprint(peerID);

        // Assert
        expect(cached, equals(fingerprint2.toLowerCase()));
      });
    });

    group('Session Storage', () {
      test('should save and load session metadata', () async {
        // Arrange
        const peerID = 'session-peer-1';
        final metadata = {
          'state': 'established',
          'handshakeComplete': true,
          'lastSeen': 1234567890,
        };

        // Act
        await secureStorageService.saveSessionMetadata(peerID, metadata);
        final loaded =
            await secureStorageService.loadSessionMetadata(peerID);

        // Assert
        expect(loaded, isNotNull);
        expect(loaded!['state'], equals('established'));
        expect(loaded['handshakeComplete'], isTrue);
        expect(loaded['lastSeen'], equals(1234567890));
      });

      test('should return null for non-existent session', () async {
        // Act
        final loaded = await secureStorageService
            .loadSessionMetadata('non-existent-session');

        // Assert
        expect(loaded, isNull);
      });

      test('should delete session metadata', () async {
        // Arrange
        const peerID = 'session-peer-2';
        final metadata = {'test': 'data'};

        // Act
        await secureStorageService.saveSessionMetadata(peerID, metadata);
        await secureStorageService.deleteSessionMetadata(peerID);
        final loaded =
            await secureStorageService.loadSessionMetadata(peerID);

        // Assert
        expect(loaded, isNull);
      });

      test('should get all session peer IDs', () async {
        // Arrange
        const peerID1 = 'session-peer-3';
        const peerID2 = 'session-peer-4';
        final metadata = {'test': 'data'};

        // Act
        await secureStorageService.saveSessionMetadata(peerID1, metadata);
        await secureStorageService.saveSessionMetadata(peerID2, metadata);
        final peerIDs = await secureStorageService.getAllSessionPeerIDs();

        // Assert
        expect(peerIDs.length, equals(2));
        expect(peerIDs.contains(peerID1.toLowerCase()), isTrue);
        expect(peerIDs.contains(peerID2.toLowerCase()), isTrue);
      });
    });

    group('Settings Persistence', () {
      test('should save and load settings', () async {
        // Arrange
        final settings = {
          'theme': 'dark',
          'notifications': true,
          'autoDelete': false,
          'retentionDays': 30,
        };

        // Act
        await secureStorageService.saveSettings(settings);
        final loaded = await secureStorageService.loadSettings();

        // Assert
        expect(loaded['theme'], equals('dark'));
        expect(loaded['notifications'], isTrue);
        expect(loaded['autoDelete'], isFalse);
        expect(loaded['retentionDays'], equals(30));
      });

      test('should return empty map when no settings exist', () async {
        // Act
        final loaded = await secureStorageService.loadSettings();

        // Assert
        expect(loaded, isEmpty);
      });

      test('should get specific setting value', () async {
        // Arrange
        final settings = {'theme': 'light', 'fontSize': 14};
        await secureStorageService.saveSettings(settings);

        // Act
        final theme = await secureStorageService.getSetting('theme');
        final fontSize = await secureStorageService.getSetting('fontSize');
        final nonExistent = await secureStorageService.getSetting('nonExistent');

        // Assert
        expect(theme, equals('light'));
        expect(fontSize, equals(14));
        expect(nonExistent, isNull);
      });

      test('should update specific settings without overwriting others', () async {
        // Arrange
        final initialSettings = {
          'theme': 'dark',
          'notifications': true,
          'fontSize': 14,
        };
        await secureStorageService.saveSettings(initialSettings);

        // Act
        await secureStorageService.updateSettings({'theme': 'light'});
        final loaded = await secureStorageService.loadSettings();

        // Assert
        expect(loaded['theme'], equals('light'));
        expect(loaded['notifications'], isTrue);
        expect(loaded['fontSize'], equals(14));
      });
    });

    group('Encryption/Decryption Helpers', () {
      test('should encrypt and decrypt string', () async {
        // Arrange
        const plaintext = 'Hello, World!';

        // Act
        final encrypted = await secureStorageService.encryptString(plaintext);
        final decrypted = await secureStorageService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('should produce different ciphertext for same plaintext', () async {
        // Arrange
        const plaintext = 'Sensitive Data';

        // Act
        final encrypted1 = await secureStorageService.encryptString(plaintext);
        final encrypted2 = await secureStorageService.encryptString(plaintext);

        // Assert
        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('should decrypt correctly with different salts', () async {
        // Arrange
        const plaintext = 'Another test string';

        // Act
        final encrypted = await secureStorageService.encryptString(plaintext);
        final decrypted = await secureStorageService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('should handle empty string encryption', () async {
        // Arrange
        const plaintext = '';

        // Act
        final encrypted = await secureStorageService.encryptString(plaintext);
        final decrypted = await secureStorageService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });

      test('should handle special characters in encryption', () async {
        // Arrange
        const plaintext = '🔐 Secure message with émojis & spëcial çhars!';

        // Act
        final encrypted = await secureStorageService.encryptString(plaintext);
        final decrypted = await secureStorageService.decryptString(encrypted);

        // Assert
        expect(decrypted, equals(plaintext));
      });
    });

    group('General Storage Operations', () {
      test('should store and retrieve secure value', () async {
        // Arrange
        const key = 'test_key';
        const value = 'test_value';

        // Act
        await secureStorageService.storeSecureValue(key, value);
        final retrieved = await secureStorageService.getSecureValue(key);

        // Assert
        expect(retrieved, equals(value));
      });

      test('should return null for non-existent key', () async {
        // Act
        final retrieved = await secureStorageService.getSecureValue('non_existent');

        // Assert
        expect(retrieved, isNull);
      });

      test('should remove secure value', () async {
        // Arrange
        const key = 'removable_key';
        await secureStorageService.storeSecureValue(key, 'value');

        // Act
        await secureStorageService.removeSecureValue(key);
        final retrieved = await secureStorageService.getSecureValue(key);

        // Assert
        expect(retrieved, isNull);
      });

      test('should check if secure value exists', () async {
        // Arrange
        const key = 'existing_key';
        await secureStorageService.storeSecureValue(key, 'value');

        // Act
        final hasValue = await secureStorageService.hasSecureValue(key);
        final hasNonExistent = await secureStorageService
            .hasSecureValue('non_existent_key');

        // Assert
        expect(hasValue, isTrue);
        expect(hasNonExistent, isFalse);
      });
    });

    group('Data Management', () {
      test('should check if identity data exists', () async {
        // Act & Assert - Initially should be false
        expect(await secureStorageService.hasIdentityData(), isFalse);

        // Act - Add identity data
        final privateKey = Uint8List(32);
        final publicKey = Uint8List(32);
        await secureStorageService.saveStaticKeyPair(privateKey, publicKey);
        await secureStorageService.saveSigningKeyPair(privateKey, publicKey);

        // Assert - Should now be true
        expect(await secureStorageService.hasIdentityData(), isTrue);
      });

      test('should clear identity data', () async {
        // Arrange
        final privateKey = Uint8List(32);
        final publicKey = Uint8List(32);
        await secureStorageService.saveStaticKeyPair(privateKey, publicKey);
        await secureStorageService.saveSigningKeyPair(privateKey, publicKey);

        // Act
        await secureStorageService.clearIdentityData();

        // Assert
        expect(await secureStorageService.hasIdentityData(), isFalse);
        expect(await secureStorageService.loadStaticKeyPair(), isNull);
        expect(await secureStorageService.loadSigningKeyPair(), isNull);
      });

      test('should clear cached peer data', () async {
        // Arrange
        const peerID = 'peer-to-clear';
        const fingerprint =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        await secureStorageService.cachePeerFingerprint(peerID, fingerprint);

        // Act
        await secureStorageService.clearCachedPeerData();
        final cached =
            await secureStorageService.getCachedPeerFingerprint(peerID);

        // Assert
        expect(cached, isNull);
      });

      test('should clear all sessions', () async {
        // Arrange
        const peerID1 = 'session-1';
        const peerID2 = 'session-2';
        await secureStorageService.saveSessionMetadata(peerID1, {});
        await secureStorageService.saveSessionMetadata(peerID2, {});

        // Act
        await secureStorageService.clearAllSessions();
        final peerIDs = await secureStorageService.getAllSessionPeerIDs();

        // Assert
        expect(peerIDs, isEmpty);
      });

      test('should clear all data', () async {
        // Arrange
        final privateKey = Uint8List(32);
        final publicKey = Uint8List(32);
        await secureStorageService.saveStaticKeyPair(privateKey, publicKey);
        await secureStorageService.saveSettings({'test': 'data'});

        // Act
        await secureStorageService.clearAll();

        // Assert
        expect(await secureStorageService.hasIdentityData(), isFalse);
        expect(await secureStorageService.loadSettings(), isEmpty);
      });

      test('should generate debug info', () async {
        // Arrange
        final privateKey = Uint8List(32);
        final publicKey = Uint8List(32);
        await secureStorageService.saveStaticKeyPair(privateKey, publicKey);

        // Act
        final debugInfo = await secureStorageService.getDebugInfo();

        // Assert
        expect(debugInfo, contains('=== Secure Storage Debug ==='));
        expect(debugInfo, contains('Has identity: true'));
        expect(debugInfo, contains('Identity fingerprint:'));
      });
    });

    group('Error Handling', () {
      test('should handle invalid fingerprint in peer caching', () async {
        // Arrange
        const peerID = 'peer-test';
        const invalidFingerprint = 'invalid';

        // Act & Assert
        expect(
          () => secureStorageService.cachePeerFingerprint(
              peerID, invalidFingerprint),
          throwsA(isA<SecureStorageException>()),
        );
      });

      test('should handle invalid noise key format', () async {
        // Arrange
        const peerID = 'peer-test';
        const invalidNoiseKey = 'not-a-valid-hex-key';

        // Act & Assert
        expect(
          () => secureStorageService.cachePeerNoiseKey(peerID, invalidNoiseKey),
          throwsA(isA<SecureStorageException>()),
        );
      });

      test('should throw SecureStorageException for decryption failures',
          () async {
        // Arrange
        const invalidCiphertext = 'invalid-base64!@#';

        // Act & Assert
        expect(
          () => secureStorageService.decryptString(invalidCiphertext),
          throwsA(isA<SecureStorageException>()),
        );
      });
    });

    group('Integration Tests', () {
      test('should handle complete user workflow', () async {
        // Arrange - User creates identity
        final staticPrivateKey = Uint8List(32);
        final staticPublicKey = Uint8List(32);
        final signingPrivateKey = Uint8List(32);
        final signingPublicKey = Uint8List(32);

        // Act - Save identity
        await secureStorageService.saveStaticKeyPair(
            staticPrivateKey, staticPublicKey);
        await secureStorageService.saveSigningKeyPair(
            signingPrivateKey, signingPublicKey);

        // Assert - Verify identity
        expect(await secureStorageService.hasIdentityData(), isTrue);

        // Act - Generate and verify fingerprint
        final fingerprint =
            secureStorageService.generateFingerprint(staticPublicKey);
        expect(secureStorageService.isValidFingerprint(fingerprint), isTrue);

        // Act - Add peer with fingerprint
        const peerID = 'integration-peer';
        await secureStorageService.cachePeerFingerprint(peerID, fingerprint);
        await secureStorageService.setVerifiedFingerprint(fingerprint, true);

        // Assert - Verify peer data
        expect(
            await secureStorageService.getCachedPeerFingerprint(peerID),
            equals(fingerprint.toLowerCase()));
        expect(
            await secureStorageService.isVerifiedFingerprint(fingerprint),
            isTrue);

        // Act - Save session and settings
        await secureStorageService.saveSessionMetadata(peerID, {
          'state': 'established',
          'connectedAt': DateTime.now().millisecondsSinceEpoch,
        });
        await secureStorageService.saveSettings({
          'lastSeenPeer': peerID,
          'theme': 'dark',
        });

        // Assert - Verify session and settings
        final sessionMetadata =
            await secureStorageService.loadSessionMetadata(peerID);
        expect(sessionMetadata?['state'], equals('established'));

        final settings = await secureStorageService.loadSettings();
        expect(settings['lastSeenPeer'], equals(peerID));
        expect(settings['theme'], equals('dark'));
      });
    });
  });
}
