import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/mesh/packet_relay_manager.dart';
import 'package:bitchat/data/models/routed_packet.dart';

/// Simple fake delegate implementing PacketRelayManagerDelegate.
class FakePacketRelayManagerDelegate implements PacketRelayManagerDelegate {
  int _networkSize = 10;
  Uint8List _broadcastRecipient = Uint8List(8);

  String? lastSentPeerId;
  RoutedPacket? lastSentPacket;
  RoutedPacket? lastBroadcastPacket;

  bool sendToPeerResult = true;

  @override
  int getNetworkSize() => _networkSize;

  set networkSize(int v) => _networkSize = v;

  @override
  Uint8List getBroadcastRecipient() => _broadcastRecipient;

  set broadcastRecipient(Uint8List r) => _broadcastRecipient = r;

  @override
  void broadcastPacket(RoutedPacket routed) {
    lastBroadcastPacket = routed;
  }

  @override
  bool sendToPeer(String peerID, RoutedPacket routed) {
    lastSentPeerId = peerID;
    lastSentPacket = routed;
    return sendToPeerResult;
  }

  void reset() {
    lastSentPeerId = null;
    lastSentPacket = null;
    lastBroadcastPacket = null;
    sendToPeerResult = true;
  }
}

Uint8List hexStringToPeerBytes(String hex) {
  final result = Uint8List(8);
  int idx = 0;
  int out = 0;
  while (idx + 1 < hex.length && out < 8) {
    final byteStr = hex.substring(idx, idx + 2);
    try {
      result[out] = int.parse(byteStr, radix: 16);
    } catch (e) {
      result[out] = 0;
    }
    idx += 2;
    out++;
  }
  return result;
}

void main() {
  late PacketRelayManager packetRelayManager;
  late FakePacketRelayManagerDelegate delegate;

  const myPeerID = '1111111111111111';
  const otherPeerID = '2222222222222222';
  const nextHopPeerID = '3333333333333333';
  const finalRecipientID = '4444444444444444';

  setUp(() {
    delegate = FakePacketRelayManagerDelegate();
    packetRelayManager = PacketRelayManager(myPeerID);
    packetRelayManager.delegate = delegate;

    delegate.networkSize = 10;
    delegate.broadcastRecipient = Uint8List.fromList(List.filled(8, 0));
  });

  BitchatPacket createPacket(List<Uint8List>? route, {String? recipient}) {
    return BitchatPacket(
      type: 1,
      senderID: hexStringToPeerBytes(otherPeerID),
      recipientID: recipient != null ? hexStringToPeerBytes(recipient) : null,
      timestamp: DateTime.now(),
      payload: Uint8List.fromList('hello'.codeUnits),
      ttl: 5,
      route: route,
    );
  }

  test('packet with duplicate hops is dropped', () async {
    final route = [
      hexStringToPeerBytes(nextHopPeerID),
      hexStringToPeerBytes(nextHopPeerID),
    ];
    final packet = createPacket(route);
    final routedPacket = RoutedPacket(packet: packet, peerID: otherPeerID);

    await packetRelayManager.handlePacketRelay(routedPacket);

    expect(delegate.lastSentPeerId, isNull);
    expect(delegate.lastBroadcastPacket, isNull);
  });

  test('valid source-routed packet is relayed to next hop', () async {
    final route = [
      hexStringToPeerBytes(myPeerID),
      hexStringToPeerBytes(nextHopPeerID),
    ];
    final packet = createPacket(route, recipient: finalRecipientID);
    final routedPacket = RoutedPacket(packet: packet, peerID: otherPeerID);

    delegate.sendToPeerResult = true;

    await packetRelayManager.handlePacketRelay(routedPacket);

    expect(delegate.lastSentPeerId, equals(nextHopPeerID));
    expect(delegate.lastSentPacket, isNotNull);
    expect(delegate.lastBroadcastPacket, isNull);
  });

  test('last hop does not relay further', () async {
    final route = [
      hexStringToPeerBytes(myPeerID),
    ];
    final packet = createPacket(route, recipient: finalRecipientID);
    final routedPacket = RoutedPacket(packet: packet, peerID: otherPeerID);

    delegate.sendToPeerResult = true;

    await packetRelayManager.handlePacketRelay(routedPacket);

    expect(delegate.lastSentPeerId, equals(finalRecipientID));
    expect(delegate.lastSentPacket, isNotNull);
    expect(delegate.lastBroadcastPacket, isNull);
  });

  test('packet with empty route is broadcast', () async {
    final packet = createPacket(null);
    final routedPacket = RoutedPacket(packet: packet, peerID: otherPeerID);

    await packetRelayManager.handlePacketRelay(routedPacket);

    expect(delegate.lastSentPeerId, isNull);
    expect(delegate.lastBroadcastPacket, isNotNull);
  });
}
