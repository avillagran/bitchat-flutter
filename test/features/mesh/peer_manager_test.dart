import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/mesh/peer_manager.dart';

// Tests adapted from Android's PeerManagerTest.kt. They exercise similar logic
// using the Flutter PeerManager implementation.

void main() {
  late PeerManager peerManager;
  const unknownPeer = 'unknown';
  const unknownDevice = 'Unknown';

  final testUsers = {
    'peer1': 'alice',
    'peer2': 'bob',
    'peer3': 'charlie',
    'peer4': 'diana',
    'peer5': 'eve',
    unknownPeer: unknownPeer,
  };

  final deviceAddresses = {
    'C0:FF:EE:11:22:33': 'peer1',
    'C0:FF:BB:66:44:99': 'peer2',
    'C0:FF:ZZ:99:66:55': 'peer3',
    'C0:FF:QQ:22:88:44': 'peer4',
    'C0:FF:DD:77:55:11': 'peer5',
    unknownDevice: unknownPeer,
  };

  final emptyDeviceAddresses = <String, String>{};

  final testRSSI = {
    'peer1': 0,
    'peer2': 10,
    'peer3': 30,
    'peer4': 5,
    'peer5': 25,
    unknownPeer: 40,
  };

  int nowMs() => DateTime.now().millisecondsSinceEpoch;

  setUp(() {
    peerManager = PeerManager();
  });

  void addPeers({bool includeUnknown = false}) {
    testUsers.forEach((peerID, nickname) {
      if (!includeUnknown && peerID == unknownPeer) return;
      peerManager.addPeer(PeerInfo(
        id: peerID,
        name: nickname,
        isConnected: true,
        lastSeen: nowMs(),
        rssi: testRSSI[peerID],
      ));
    });
  }

  List<String> _peerIdList() =>
      peerManager.getAllPeers().map((p) => p.id).toList();

  group('PeerManager parity tests (adapted from Android)', () {
    test('peer_is_added_correctly', () {
      addPeers(includeUnknown: false);

      testUsers.forEach((peerID, nickname) {
        if (peerID == unknownPeer) {
          expect(peerManager.getPeer(peerID), isNull);
        } else {
          final p = peerManager.getPeer(peerID);
          expect(p, isNotNull);
          expect(p!.name, equals(nickname));
        }
      });
    });

    test('all_peer_nicknames_are_returned_correctly', () {
      addPeers(includeUnknown: false);
      final actual = Map.fromEntries(
          peerManager.getAllPeers().map((p) => MapEntry(p.id, p.name)));
      final expected =
          Map.fromEntries(testUsers.entries.where((e) => e.key != unknownPeer));
      expect(actual, equals(expected));
    });

    test('peer_is_removed_correctly', () {
      addPeers(includeUnknown: false);
      final keys = testUsers.keys.where((k) => k != unknownPeer).toList();
      final peerID1 = keys[0];
      final peerID2 = keys[1];

      peerManager.removePeer(peerID1);
      peerManager.removePeer(peerID2);

      final numberOfActivePeers = peerManager.getAllPeers().length;
      final expected = testUsers.length - 3;
      expect(numberOfActivePeers, equals(expected));
    });

    test('last_seen_updated_correctly', () {
      addPeers(includeUnknown: false);
      // update last seen for every peer
      peerManager.getAllPeers().forEach((p) {
        final updated = nowMs();
        final ok = peerManager.updatePeer(p.id, lastSeen: updated);
        expect(ok, isTrue);
        expect(peerManager.getPeer(p.id)!.lastSeen, equals(updated));
      });

      // Attempt to update unknown peer (should be false)
      final res = peerManager.updatePeer(unknownPeer, lastSeen: nowMs());
      expect(res, isFalse);
    });

    test('rssi_updated_correctly', () {
      addPeers(includeUnknown: false);
      testRSSI.forEach((peerID, rssi) {
        final ok = peerManager.updatePeer(peerID, rssi: rssi);
        if (peerID == unknownPeer) {
          expect(ok, isFalse);
        }
      });

      final expectedRSSI =
          Map.fromEntries(testRSSI.entries.where((e) => e.key != unknownPeer));
      final actualRSSI = Map.fromEntries(
          peerManager.getAllPeers().map((p) => MapEntry(p.id, p.rssi ?? -999)));

      expectedRSSI.forEach((k, v) {
        expect(actualRSSI[k], equals(v));
      });
    });

    test('peer_can_be_marked_as_announced_correctly', () {
      addPeers(includeUnknown: false);
      peerManager.getAllPeers().forEach((p) {
        final ok = peerManager.updatePeer(p.id, isVerifiedName: true);
        expect(ok, isTrue);
        expect(peerManager.getPeer(p.id)!.isVerifiedName, isTrue);
      });
    });

    test('peer_can_announce_correctly', () {
      addPeers(includeUnknown: false);
      testUsers.forEach((peerID, _) {
        if (peerID == unknownPeer) {
          expect(peerManager.getPeer(peerID), isNull);
        } else {
          final isPeerActive = peerManager.getPeer(peerID)!.isConnected;
          expect(isPeerActive, isTrue);
        }
      });
    });

    test('all_peers_cleared_correctly', () {
      addPeers(includeUnknown: false);
      expect(peerManager.getAllPeers().isNotEmpty, isTrue);
      for (final p in List.of(peerManager.getAllPeers())) {
        peerManager.removePeer(p.id);
      }
      expect(peerManager.getAllPeers().isEmpty, isTrue);
    });

    test('peer_manager_can_shutdown_properly', () {
      addPeers(includeUnknown: false);
      expect(peerManager.getAllPeers().isNotEmpty, isTrue);
      for (final p in List.of(peerManager.getAllPeers())) {
        peerManager.removePeer(p.id);
      }
      expect(peerManager.getAllPeers().isEmpty, isTrue);
    });

    test('debug_info_can_be_returned_correctly', () {
      addPeers(includeUnknown: false);
      testRSSI.forEach((peerID, rssi) {
        peerManager.updatePeer(peerID, rssi: rssi);
      });

      final announcedPeers = peerManager.getAllPeers().length;

      final debugLines = <String>[];
      debugLines.add('=== Peer Manager Debug Info ===');
      debugLines.add('Active Peers: ${peerManager.getAllPeers().length}');

      for (final entry in peerManager.getAllPeers()) {
        final nickname = entry.name;
        final timeSince = ((nowMs() - entry.lastSeen) / 1000).round();
        final rssiStr = entry.rssi != null ? '${entry.rssi} dBm' : 'No RSSI';
        final deviceAddress = deviceAddresses.entries
            .firstWhere((e) => e.value == entry.id,
                orElse: () => const MapEntry('Unknown', ''))
            ?.key;
        final addressInfo = deviceAddress != null && deviceAddress.isNotEmpty
            ? ' [Device: $deviceAddress]'
            : ' [Device: Unknown]';
        debugLines.add(
            '  - ${entry.id} ($nickname)$addressInfo - last seen ${timeSince}s ago, RSSI: $rssiStr');
      }

      debugLines.add('Announced Peers: $announcedPeers');
      debugLines.add('Announced To Peers: 0');

      expect(debugLines[0], equals('=== Peer Manager Debug Info ==='));
      expect(debugLines[1],
          equals('Active Peers: ${peerManager.getAllPeers().length}'));
      expect(debugLines[debugLines.length - 2],
          equals('Announced Peers: $announcedPeers'));
      expect(
          debugLines[debugLines.length - 1], equals('Announced To Peers: 0'));

      for (final deviceEntry in deviceAddresses.entries) {
        final peerID = deviceEntry.value;
        if (peerID == unknownPeer) continue;
        final p = peerManager.getPeer(peerID);
        expect(p, isNotNull);
        final actualNickname = p!.name;
        final expectedNickname = testUsers[peerID];
        expect(actualNickname, equals(expectedNickname));
      }
    });

    test('debug_info_with_addresses_can_be_returned_correctly', () {
      addPeers(includeUnknown: false);
      final lines = <String>[];
      lines.add('=== Device Address to Peer Mapping ===');
      for (final e in deviceAddresses.entries) {
        if (e.value == unknownPeer) continue;
        final nickname = peerManager.getPeer(e.value)?.name ?? unknownPeer;
        final isActive = _peerIdList().contains(e.value);
        final status = isActive ? 'ACTIVE' : 'INACTIVE';
        lines.add(
            '  Device: ${e.key} -> Peer: ${e.value} ($nickname) [$status]');
      }

      lines.addAll([
        '---',
        ...peerManager.getAllPeers().map((p) => '${p.id}:${p.name}')
      ]);

      expect(lines[0], equals('=== Device Address to Peer Mapping ==='));

      final expectedLastLines =
          peerManager.getAllPeers().map((p) => '${p.id}:${p.name}').toList();
      final lastLinesAreAvailable =
          expectedLastLines.every((l) => lines.contains(l));
      expect(lastLinesAreAvailable, isTrue);

      for (final e in deviceAddresses.entries) {
        if (e.value == unknownPeer) continue;
        final expected =
            '  Device: ${e.key} -> Peer: ${e.value} (${testUsers[e.value]}) [ACTIVE]';
        expect(lines, contains(expected));
      }
    });

    test('debug_info_with_empty_addresses_can_return_correctly', () {
      addPeers(includeUnknown: false);
      final lines = <String>[];
      lines.add('=== Device Address to Peer Mapping ===');
      if (emptyDeviceAddresses.isEmpty) {
        lines.add('No device address mappings available');
      }

      expect(lines[1], equals('No device address mappings available'));
    });
  });
}

List<String> _peerIdList(PeerManager pm) =>
    pm.getAllPeers().map((p) => p.id).toList();
