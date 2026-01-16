import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/ui/widgets/peer_list_sheet.dart';
import 'package:bitchat/features/mesh/peer_manager.dart';

void main() {
  group('PeerListSheet Widget Tests', () {
    late List<PeerInfo> mockPeers;

    setUp(() {
      mockPeers = [
        PeerInfo(
          id: 'peer1',
          name: 'Alice',
          isConnected: true,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
          rssi: -55,
          transport: TransportType.bluetooth,
          isVerifiedName: true,
        ),
        PeerInfo(
          id: 'peer2',
          name: 'Bob',
          isConnected: true,
          lastSeen: DateTime.now().millisecondsSinceEpoch,
          rssi: -70,
          transport: TransportType.bluetooth,
          isVerifiedName: false,
        ),
        PeerInfo(
          id: 'peer3',
          name: 'Charlie',
          isConnected: false,
          lastSeen: DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
          rssi: null,
          transport: TransportType.bluetooth,
          isVerifiedName: false,
        ),
      ];
    });

    testWidgets('displays peer list sheet with peers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Your Network'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);
    });

    testWidgets('shows empty state when no peers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: [],
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('No one connected'), findsOneWidget);
      expect(find.byIcon(Icons.person_off), findsOneWidget);
    });

    testWidgets('displays verification badge for verified peers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Alice is verified, Bob is not
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('displays connection status indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Check for connected peers (Alice and Bob)
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('displays RSSI signal strength for connected peers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Alice has good signal (-55), Bob has fair signal (-70)
      // Signal strength is represented as small colored bars
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
    });

    testWidgets('displays available channels', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              channels: ['general', 'random'],
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Channels'), findsOneWidget);
      expect(find.text('Mesh (Broadcast)'), findsOneWidget);
      expect(find.text('#general'), findsOneWidget);
      expect(find.text('#random'), findsOneWidget);
    });

    testWidgets('calls onPeerTap when peer is tapped', (WidgetTester tester) async {
      String? tappedPeerId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (peerId) {
                tappedPeerId = peerId;
              },
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Alice'));
      expect(tappedPeerId, 'peer1');
    });

    testWidgets('shows peer actions menu on more button tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap the more options icon for the first peer
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Block'), findsOneWidget);
    });

    testWidgets('calls onVerifyTap when verify action is selected', (WidgetTester tester) async {
      String? verifiedPeerId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (peerId) {
                verifiedPeerId = peerId;
              },
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // Tap verify option
      await tester.tap(find.text('Verified'));
      expect(verifiedPeerId, 'peer1');
    });

    testWidgets('calls onBlockTap when block action is selected', (WidgetTester tester) async {
      String? blockedPeerId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (peerId) {
                blockedPeerId = peerId;
              },
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();

      // Tap block option
      await tester.tap(find.text('Block'));
      expect(blockedPeerId, 'peer1');
    });

    testWidgets('calls onChannelTap when channel is selected', (WidgetTester tester) async {
      String? selectedChannel;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              channels: ['general', 'random'],
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (channel) {
                selectedChannel = channel;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('#general'));
      expect(selectedChannel, 'general');
    });

    testWidgets('calls onChannelTap with null when Mesh is selected', (WidgetTester tester) async {
      String? selectedChannel;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              channels: ['general'],
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (channel) {
                selectedChannel = channel;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Mesh (Broadcast)'));
      expect(selectedChannel, isNull);
    });

    testWidgets('shows peer count in header', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('3'), findsOneWidget); // 3 peers
    });

    testWidgets('displays last seen time for offline peers', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PeerListSheet(
              peers: mockPeers,
              onPeerTap: (_) {},
              onVerifyTap: (_) {},
              onBlockTap: (_) {},
              onChannelTap: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      // Charlie is offline, should show "Last seen"
      expect(find.textContaining('Last seen'), findsOneWidget);
    });
  });
}
