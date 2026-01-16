import 'dart:typed_data';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/features/mesh/fragment_manager.dart';
import 'package:bitchat/features/mesh/packet_relay_manager.dart';

class PacketProcessor {
  final FragmentManager _fragmentManager;
  final PacketRelayManager _relayManager;

  PacketProcessor(this._fragmentManager, this._relayManager);

  Future<void> processPacket(RoutedPacket routed) async {
    final packet = routed.packet;

    // Handle fragments
    if (packet.type == 0x20) {
      final reassembled = _fragmentManager.handleFragment(packet);
      if (reassembled != null) {
        _handleCompletePacket(routed.copyWith(packet: reassembled));
      }
    } else {
      _handleCompletePacket(routed);
    }

    // Relay logic
    await _relayManager.handlePacketRelay(routed);
  }

  void _handleCompletePacket(RoutedPacket routed) {
    print("Mesh: Processing complete packet of type ${routed.packet.type}");
  }
}
