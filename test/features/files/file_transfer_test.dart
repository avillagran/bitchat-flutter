import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/data/models/bitchat_file_packet.dart';
import 'package:bitchat/features/files/file_transfer.dart';

void main() {
  group('FileTransfer', () {
    test('encode and decode file packet preserves data', () {
      final content = Uint8List.fromList(List.generate(1024, (i) => i % 256));
      final packet = BitchatFilePacket(
        fileName: 'test.png',
        mimeType: 'image/png',
        fileSize: content.length,
        content: content,
      );

      final encoded = packet.encode();
      expect(encoded, isNotNull);

      final decoded = BitchatFilePacket.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.fileName, equals(packet.fileName));
      expect(decoded.mimeType, equals(packet.mimeType));
      expect(decoded.fileSize, equals(packet.fileSize));
      expect(decoded.content!.length, equals(packet.content!.length));
      expect(decoded.content, equals(packet.content));
    });

    test('file packet metadata encoding: filename and filesize endianness', () {
      final content = Uint8List.fromList([1, 2, 3, 4]);
      final packet = BitchatFilePacket(
        fileName: 'myimage.jpg',
        mimeType: 'image/jpeg',
        fileSize: 0x12345678,
        content: content,
      );

      final encoded = packet.encode()!;
      // check first type is filename (0x01)
      expect(encoded[0], equals(0x01));

      // find filesize TLV (0x02) and ensure big endian
      int off = 0;
      int found = 0;
      while (off < encoded.length - 1) {
        if (encoded[off] == 0x02) {
          // length is next 2 bytes (big endian)
          final len = (encoded[off + 1] << 8) | encoded[off + 2];
          expect(len, equals(4));
          final size = (encoded[off + 3] << 24) |
              (encoded[off + 4] << 16) |
              (encoded[off + 5] << 8) |
              (encoded[off + 6]);
          expect(size, equals(0x12345678));
          found++;
          break;
        }
        off++;
      }
      expect(found, greaterThan(0));
    });

    test('fragmentation and reassembly works and reports progress', () async {
      final content = Uint8List.fromList(List.generate(2000, (i) => i % 256));
      final file = BitchatFilePacket(
        fileName: 'big.bin',
        mimeType: 'application/octet-stream',
        fileSize: content.length,
        content: content,
      );

      final manager = FileTransferManager();
      final packet = manager.createFilePacket(file);

      // create fragments
      final fragments =
          manager.fragmentPacket(packet, mySenderID: Uint8List(8));
      expect(fragments.length, greaterThan(1));

      // collect progress events
      final progresses = <double>[];
      final sub = manager.progressStream.listen((p) {
        progresses.add(p.progress);
      });

      var reassembled;
      for (final frag in fragments) {
        reassembled = await manager.handleIncomingFragment(frag);
      }

      // Wait a tick for progress stream
      await Future.delayed(Duration(milliseconds: 10));

      expect(reassembled, isNotNull);
      expect(progresses, isNotEmpty);
      expect(progresses.last, equals(1.0));

      sub.cancel();
      manager.dispose();
    });

    test('missing fragment produces error / no reassembly', () async {
      final content = Uint8List.fromList(List.generate(2000, (i) => i % 256));
      final file = BitchatFilePacket(
        fileName: 'big2.bin',
        mimeType: 'application/octet-stream',
        fileSize: content.length,
        content: content,
      );

      final manager = FileTransferManager();
      final packet = manager.createFilePacket(file);
      final fragments =
          manager.fragmentPacket(packet, mySenderID: Uint8List(8));

      // drop the last fragment
      final toSend = fragments.sublist(0, fragments.length - 1);

      var reassembled;
      for (final frag in toSend) {
        reassembled = await manager.handleIncomingFragment(frag);
      }

      // Should not have reassembled
      expect(reassembled, isNull);
      manager.dispose();
    });
  });
}
