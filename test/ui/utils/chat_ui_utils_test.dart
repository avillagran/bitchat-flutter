import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/ui/utils/chat_ui_utils.dart';

void main() {
  group('ChatUiUtils color system', () {
    test('djb2 hash produces consistent results', () {
      int djb2(String s) {
        int hash = 5381;
        final bytes = s.codeUnits;
        for (final b in bytes) {
          hash = ((hash << 5) + hash) + b;
          hash = hash & 0xFFFFFFFF; // 32-bit unsigned
        }
        return hash;
      }

      final seeds = [
        'alice',
        'bob',
        'charlie',
        'diana',
        'eve',
        'nostr:npub1abcd'
      ];

      for (final s in seeds) {
        final h1 = djb2(s);
        final h2 = djb2(s);
        expect(h1, equals(h2), reason: 'djb2 should be deterministic for "$s"');
      }
    });

    test('same peer ID always gets same color', () {
      final seed = ChatUiUtils.seedForPeer('npub12345');
      final c1 = ChatUiUtils.colorForPeerSeed(seed, isDark: false);
      final c2 = ChatUiUtils.colorForPeerSeed(seed, isDark: false);
      expect(c1.value, equals(c2.value));
    });

    test('different peer IDs get different colors', () {
      final seedA = ChatUiUtils.seedForPeer('alice');
      final seedB = ChatUiUtils.seedForPeer('bob');
      final colorA = ChatUiUtils.colorForPeerSeed(seedA, isDark: false);
      final colorB = ChatUiUtils.colorForPeerSeed(seedB, isDark: false);
      expect(colorA.value, isNot(equals(colorB.value)));
    });

    test('colors are visible (not too dark or too light)', () {
      final seeds = [
        'alice',
        'bob',
        'charlie',
        'diana',
        'eve',
        'noise:00112233445566778899aabbccddeeff',
        'nostr:npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq'
      ];

      for (final s in seeds) {
        final seed = ChatUiUtils.seedForPeer(s);
        final colorLight = ChatUiUtils.colorForPeerSeed(seed, isDark: false);
        final colorDark = ChatUiUtils.colorForPeerSeed(seed, isDark: true);

        double lumLight = colorLight.computeLuminance();
        double lumDark = colorDark.computeLuminance();

        // Ensure luminance is not almost black or almost white (allow wider range)
        expect(lumLight, inExclusiveRange(0.01, 0.99),
            reason: 'Light-mode color for $s has bad luminance: $lumLight');
        expect(lumDark, inExclusiveRange(0.01, 0.99),
            reason: 'Dark-mode color for $s has bad luminance: $lumDark');
      }
    });

    test('hash collisions are rare across many peers', () {
      const int n = 500;
      final values = <int>{};

      for (int i = 0; i < n; i++) {
        final peer = 'user$i';
        final seed = ChatUiUtils.seedForPeer(peer);
        final color = ChatUiUtils.colorForPeerSeed(seed, isDark: false);
        values.add(color.value);
      }

      final unique = values.length;
      final collisions = n - unique;

      // Expect collisions to be reasonably rare. Allow up to 40% collisions
      final maxAllowed = (n * 0.40).floor();
      expect(collisions <= maxAllowed, isTrue,
          reason:
              'Too many color collisions: $collisions out of $n (allowed: $maxAllowed)');
    });
  });
}
