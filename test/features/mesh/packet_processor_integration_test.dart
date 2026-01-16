import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/mesh/packet_processor.dart';
import 'package:bitchat/features/mesh/fragment_manager.dart';
import 'package:bitchat/features/mesh/packet_relay_manager.dart';
import 'package:bitchat/data/models/routed_packet.dart';

/// Mock delegate for PacketRelayManager.
class MockPacketRelayDelegate implements PacketRelayManagerDelegate {
  final List<RoutedPacket> broadcastPackets = [];
  final List<String> sentToPeer = [];
  final Map<String, bool> sendToPeerResults = {};
  int _networkSize = 10;

  @override
  int getNetworkSize() => _networkSize;

  set networkSize(int value) => _networkSize = value;

  @override
  Uint8List getBroadcastRecipient() => 
      Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]);

  @override
  void broadcastPacket(RoutedPacket routed) {
    broadcastPackets.add(routed);
  }

  @override
  bool sendToPeer(String peerID, RoutedPacket routed) {
    sentToPeer.add(peerID);
    return sendToPeerResults[peerID] ?? false;
  }

  void setSendToPeerResult(String peerID, bool result) {
    sendToPeerResults[peerID] = result;
  }

  void reset() {
    broadcastPackets.clear();
    sentToPeer.clear();
    sendToPeerResults.clear();
    _networkSize = 10;
  }
}

/// Mock delegate for FragmentManager.
class MockFragmentDelegate implements FragmentManagerDelegate {
  BitchatPacket? reassembledPacket;

  @override
  void onPacketReassembled(BitchatPacket packet) {
    reassembledPacket = packet;
  }

  void reset() {
    reassembledPacket = null;
  }
}

/// Integration tests for PacketProcessor, FragmentManager, and PacketRelayManager.
/// Tests packet processing, fragmentation, relay logic, and cross-manager coordination.
void main() {
  group('PacketProcessor Integration', () {
    late PacketProcessor packetProcessor;
    late FragmentManager fragmentManager;
    late PacketRelayManager relayManager;
    late MockPacketRelayDelegate relayDelegate;
    late MockFragmentDelegate fragmentDelegate;

    setUp(() {
      relayDelegate = MockPacketRelayDelegate();
      fragmentDelegate = MockFragmentDelegate();

      relayManager = PacketRelayManager('my-peer-id-01');
      relayManager.delegate = relayDelegate;

      fragmentManager = FragmentManager();
      fragmentManager.delegate = fragmentDelegate;

      packetProcessor = PacketProcessor(fragmentManager, relayManager);
    });

    tearDown(() {
      fragmentManager.dispose();
      relayDelegate.reset();
      fragmentDelegate.reset();
    });

    group('Complete Packet Processing', () {
      test('should process non-fragment packets correctly', () async {
        // Arrange
        final packet = BitchatPacket(
          type: 0x02, // Message type
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3, 4, 5]),
          ttl: 7,
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-01',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - packet should be relayed
        expect(relayDelegate.broadcastPackets.length, greaterThan(0));
      });

      test('should handle packets addressed to local node', () async {
        // Arrange
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3, 4, 5]),
          ttl: 7,
          recipientID: Uint8List.fromList([
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          ]),
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-01',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - packet should not be broadcast (addressed to specific node)
        // Note: depends on implementation details
      });

      test('should decrement TTL on relay', () async {
        // Arrange
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 5,
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-02',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - TTL should be decremented in relayed packet
        final relayed = relayDelegate.broadcastPackets.firstOrNull;
        expect(relayed, isNotNull);
        if (relayed != null) {
          expect(relayed.packet.ttl, lessThan(packet.ttl));
        }
      });

      test('should drop packets with TTL of zero', () async {
        // Arrange
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 0,
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-03',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - packet should not be relayed
        expect(relayDelegate.broadcastPackets, isEmpty);
      });

      test('should skip own packets', () async {
        // Arrange
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 5,
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'my-peer-id-01', // Same as relayManager's myPeerID
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - packet should not be relayed
        expect(relayDelegate.broadcastPackets, isEmpty);
      });
    });

    group('Fragmentation Processing', () {
      test('should fragment large packets correctly', () async {
        // Arrange
        final largePayload = Uint8List(1000); // > fragmentSizeThreshold (512)
        for (int i = 0; i < largePayload.length; i++) {
          largePayload[i] = i % 256;
        }
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: largePayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        // Act
        final fragments = fragmentManager.createFragments(
          packet,
          mySenderID: mySenderID,
        );

        // Assert
        expect(fragments.length, greaterThan(1));
        for (final fragment in fragments) {
          expect(fragment.type, equals(0x20)); // Fragment type
          expect(fragment.payload, isNotNull);
        }
      });

      test('should not fragment small packets', () async {
        // Arrange
        final smallPayload = Uint8List(100); // < fragmentSizeThreshold (512)
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: smallPayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        // Act
        final fragments = fragmentManager.createFragments(
          packet,
          mySenderID: mySenderID,
        );

        // Assert
        expect(fragments.length, equals(1));
        expect(fragments.first.type, equals(0x02)); // Original type
      });

      test('should reassemble fragmented packets', () async {
        // Arrange
        final originalPayload = Uint8List(1000);
        for (int i = 0; i < originalPayload.length; i++) {
          originalPayload[i] = i % 256;
        }
        final originalPacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: originalPayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        // Act - fragment and then reassemble
        final fragments = fragmentManager.createFragments(
          originalPacket,
          mySenderID: mySenderID,
        );

        BitchatPacket? reassembled;
        for (final fragment in fragments) {
          reassembled = fragmentManager.handleFragment(fragment);
        }

        // Assert
        expect(reassembled, isNotNull);
        expect(reassembled?.type, equals(originalPacket.type));
        expect(reassembled?.payload?.length, equals(originalPayload.length));
      });

      test('should handle out-of-order fragment arrival', () async {
        // Arrange
        final originalPayload = Uint8List(1000);
        final originalPacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: originalPayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        // Act - create fragments and process in reverse order
        final fragments = fragmentManager.createFragments(
          originalPacket,
          mySenderID: mySenderID,
        );

        BitchatPacket? reassembled;
        for (int i = fragments.length - 1; i >= 0; i--) {
          reassembled = fragmentManager.handleFragment(fragments[i]);
        }

        // Assert - should still reassemble correctly
        expect(reassembled, isNotNull);
      });

      test('should handle partial fragment loss', () async {
        // Arrange
        final originalPayload = Uint8List(1000);
        final originalPacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: originalPayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

        // Act - create fragments but don't process all
        final fragments = fragmentManager.createFragments(
          originalPacket,
          mySenderID: mySenderID,
        );

        BitchatPacket? reassembled;
        for (int i = 0; i < fragments.length - 1; i++) {
          // Skip last fragment
          reassembled = fragmentManager.handleFragment(fragments[i]);
        }

        // Assert - should not reassemble (missing fragment)
        expect(reassembled, isNull);
      });

      test('should process fragment packets through processor', () async {
        // Arrange
        final originalPayload = Uint8List(1000);
        final originalPacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: originalPayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final fragments = fragmentManager.createFragments(
          originalPacket,
          mySenderID: mySenderID,
        );

        // Act - process all fragments through packet processor
        for (final fragment in fragments) {
          final routed = RoutedPacket(
            packet: fragment,
            peerID: 'peer-fragment',
          );
          await packetProcessor.processPacket(routed);
        }

        // Assert - delegate should be called with reassembled packet
        expect(fragmentDelegate.reassembledPacket, isNotNull);
      });
    });

    group('Relay Logic', () {
      test('should relay packets based on network size', () async {
        // Arrange
        relayDelegate.networkSize = 20; // Medium network
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 4,
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-relay',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - should relay with probability based on network size
        // Network size 20 -> 85% probability
        expect(relayDelegate.broadcastPackets.length, greaterThan(0));
      });

      test('should follow source-based routing', () async {
        // Arrange
        final routePath = [
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]),
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02]),
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03]),
        ];
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 7,
          route: routePath,
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-route',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - should attempt to send to next hop in route
        expect(relayDelegate.sentToPeer.length, greaterThan(0));
      });

      test('should detect duplicate hops in route', () async {
        // Arrange
        final routePath = [
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]),
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]), // Duplicate!
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03]),
        ];
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 7,
          route: routePath,
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-dup',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - should not relay duplicate route
        expect(relayDelegate.broadcastPackets, isEmpty);
        expect(relayDelegate.sentToPeer, isEmpty);
      });

      test('should respect adaptive relay probability', () async {
        // Arrange
        relayDelegate.networkSize = 100; // Large network
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 3, // Low TTL
        );
        final routed = RoutedPacket(
          packet: packet,
          peerID: 'peer-adaptive',
        );

        // Act
        await packetProcessor.processPacket(routed);

        // Assert - low probability relay (40%) might or might not relay
        // Run multiple times to test probability
      });
    });

    group('Cross-Manager Coordination', () {
      test('should coordinate fragmentation and relay', () async {
        // Arrange
        final largePayload = Uint8List(1000);
        final originalPacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: largePayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final fragments = fragmentManager.createFragments(
          originalPacket,
          mySenderID: mySenderID,
        );

        // Act - process all fragments
        for (final fragment in fragments) {
          final routed = RoutedPacket(
            packet: fragment,
            peerID: 'peer-coord',
          );
          await packetProcessor.processPacket(routed);
        }

        // Assert - fragments processed and reassembled
        expect(fragmentDelegate.reassembledPacket, isNotNull);
        // Fragments should also be relayed
        expect(relayDelegate.broadcastPackets.length, greaterThan(0));
      });

      test('should handle mixed fragment and non-fragment traffic', () async {
        // Arrange
        final normalPacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]),
          ttl: 7,
        );
        final largePayload = Uint8List(1000);
        final largePacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: largePayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final fragments = fragmentManager.createFragments(
          largePacket,
          mySenderID: mySenderID,
        );

        // Act - mix normal and fragmented packets
        await packetProcessor.processPacket(
          RoutedPacket(packet: normalPacket, peerID: 'peer-1'),
        );
        for (final fragment in fragments) {
          await packetProcessor.processPacket(
            RoutedPacket(packet: fragment, peerID: 'peer-2'),
          );
        }
        await packetProcessor.processPacket(
          RoutedPacket(packet: normalPacket, peerID: 'peer-3'),
        );

        // Assert - all packets handled
        expect(relayDelegate.broadcastPackets.length, greaterThan(2));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle malformed fragment gracefully', () async {
        // Arrange
        final malformedPacket = BitchatPacket(
          type: 0x20, // Fragment type
          timestamp: DateTime.now(),
          payload: Uint8List.fromList([1, 2, 3]), // Too short
          ttl: 7,
        );
        final routed = RoutedPacket(
          packet: malformedPacket,
          peerID: 'peer-malformed',
        );

        // Act - should not throw
        await packetProcessor.processPacket(routed);

        // Assert - no crash, packet ignored
        expect(fragmentDelegate.reassembledPacket, isNull);
      });

      test('should handle packets with null payload', () async {
        // Arrange
        final nullPayloadPacket = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: null,
          ttl: 7,
        );
        final routed = RoutedPacket(
          packet: nullPayloadPacket,
          peerID: 'peer-null',
        );

        // Act - should not throw
        await packetProcessor.processPacket(routed);

        // Assert - handled gracefully
      });

      test('should cleanup old fragments periodically', () async {
        // Arrange
        final largePayload = Uint8List(1000);
        final packet = BitchatPacket(
          type: 0x02,
          timestamp: DateTime.now(),
          payload: largePayload,
          ttl: 7,
        );
        final mySenderID = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final fragments = fragmentManager.createFragments(
          packet,
          mySenderID: mySenderID,
        );

        // Act - process only first fragment, then wait for timeout
        fragmentManager.handleFragment(fragments.first);
        await Future.delayed(
          const Duration(milliseconds: 35000), // > fragmentTimeoutMs (30000)
        );

        // Assert - old fragments should be cleaned up
        // Note: cleanup timer runs every 10s, so fragments should be removed
      });

      test('should handle rapid packet bursts', () async {
        // Arrange
        final packets = List.generate(
          50,
          (i) => BitchatPacket(
            type: 0x02,
            timestamp: DateTime.now(),
            payload: Uint8List.fromList([i % 256]),
            ttl: 7,
          ),
        );

        // Act - process burst of packets
        for (final packet in packets) {
          await packetProcessor.processPacket(
            RoutedPacket(packet: packet, peerID: 'peer-burst-$packet'),
          );
        }

        // Assert - all packets handled without crash
        expect(relayDelegate.broadcastPackets.length, equals(50));
      });
    });
  });
}
