import 'dart:convert';
import 'dart:typed_data';

import 'nostr_event.dart';

class NostrMeshSerializer {
  // Headers similar to Android implementation
  static const int TYPE_NOSTR_RELAY_REQUEST = 0x7E; // compressed marker
  static const int TYPE_NOSTR_PLAINTEXT = 0x00;

  // Serialize event to mesh packet: [1 byte header][4 bytes big-endian length][payload bytes]
  static Uint8List serializeEventForMesh(NostrEvent event,
      {bool compressed = false}) {
    final jsonStr = json.encode(event.toJson());
    final payload = utf8.encode(jsonStr);
    final header = compressed ? TYPE_NOSTR_RELAY_REQUEST : TYPE_NOSTR_PLAINTEXT;
    final length = payload.length;
    final out = BytesBuilder();
    out.add([header]);
    out.add(_intToBytes(length));
    out.add(payload);
    return out.toBytes();
  }

  static String? deserializeEventFromMesh(Uint8List packet) {
    if (packet.isEmpty) return null;
    final header = packet[0];
    if (header != TYPE_NOSTR_PLAINTEXT && header != TYPE_NOSTR_RELAY_REQUEST)
      return null;
    if (packet.length < 5) return null;
    final length = _bytesToInt(packet.sublist(1, 5));
    if (packet.length < 5 + length) return null;
    final payload = packet.sublist(5, 5 + length);
    try {
      final jsonStr = utf8.decode(payload);
      return jsonStr;
    } catch (e) {
      return null;
    }
  }

  static List<int> _intToBytes(int v) {
    return [
      (v >> 24) & 0xFF,
      (v >> 16) & 0xFF,
      (v >> 8) & 0xFF,
      v & 0xFF,
    ];
  }

  static int _bytesToInt(List<int> bytes) {
    if (bytes.length != 4) throw ArgumentError('bytes must be length 4');
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  // NIP-17 DM encryption stub: returns base64 of "encrypted:<plaintext> by <toPubkey>"
  static String encryptNip17Dm(
      String fromPrivKey, String toPubKey, String plaintext) {
    // Real implementation would perform ECIES-like encryption. For tests, return deterministic string.
    final marker = 'encrypted:';
    final content = '$marker$plaintext|to:$toPubKey|fromPriv:$fromPrivKey';
    return base64.encode(utf8.encode(content));
  }

  static String decryptNip17Dm(
      String toPrivKey, String fromPubKey, String ciphertext) {
    final decoded = utf8.decode(base64.decode(ciphertext));
    // In our stub, just return the part after marker
    if (!decoded.startsWith('encrypted:')) return '';
    final payload = decoded.substring('encrypted:'.length);
    final parts = payload.split('|');
    return parts.isNotEmpty ? parts[0] : '';
  }

  // Geohash event creation (NIP-52 style) stub: kind maybe 30023, tags contain 'geohash' tag
  static NostrEvent createGeohashEvent({
    required String id,
    required String pubkey,
    required int createdAt,
    required String geohash,
    required String content,
  }) {
    final tags = [
      ['g', geohash]
    ];
    return NostrEvent(
      id: id,
      pubkey: pubkey,
      createdAt: createdAt,
      kind: 30023,
      tags: tags,
      content: content,
      sig: '',
    );
  }
}
