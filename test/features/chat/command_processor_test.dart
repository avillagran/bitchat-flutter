import 'package:flutter_test/flutter_test.dart';
import 'package:bitchat/features/chat/command_processor.dart';
import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';
import 'package:bitchat/features/mesh/peer_manager.dart';
import 'package:bitchat/features/crypto/encryption_service.dart';
import 'package:bitchat/data/models/routed_packet.dart';

import 'package:bitchat/data/models/identity_announcement.dart';

/// Mock BluetoothMeshService for testing
class MockBluetoothMeshService extends BluetoothMeshService {
  MockBluetoothMeshService() : super(EncryptionService());

  @override
  late final String myPeerID = 'test-peer-id';

  @override
  final PeerManager peerManager = PeerManager();

  @override
  bool get isActive => true;

  @override
  Future<bool> start() async => true;

  @override
  void stop() {}

  @override
  Future<void> sendMessage(
    String content, {
    List<String>? mentions,
    String? channel,
  }) async {}

  @override
  Future<int> broadcastPacket(BitchatPacket packet) async => 0;

  @override
  Future<bool> sendPacketToPeer(String peerID, BitchatPacket packet) async =>
      true;

  @override
  void onDeviceConnected(dynamic device) {}

  @override
  void onDeviceDisconnected(dynamic device) {}

  @override
  void onPacketReceived(
    BitchatPacket packet,
    String peerID,
    dynamic device,
  ) {}
}

void main() {
  group('CommandProcessor - Parsing', () {
    late CommandProcessor processor;

    setUp(() {
      processor = CommandProcessor();
    });

    test('isCommand should return true for commands starting with /', () {
      expect(processor.isCommand('/join'), true);
      expect(processor.isCommand('/msg'), true);
      expect(processor.isCommand('/help'), true);
    });

    test('isCommand should return true for commands starting with !', () {
      expect(processor.isCommand('!join'), true);
      expect(processor.isCommand('!msg'), true);
    });

    test('isCommand should return false for regular messages', () {
      expect(processor.isCommand('hello world'), false);
      expect(processor.isCommand('This is a message'), false);
    });

    test('isCommand should return false for empty input', () {
      expect(processor.isCommand(''), false);
      expect(processor.isCommand('   '), false);
    });

    test('parseCommand should correctly parse /join command', () {
      final result = processor.parseCommand('/join #general');
      expect(result, isNotNull);
      expect(result?.command, 'join');
      expect(result?.arguments, ['#general']);
    });

    test('parseCommand should correctly parse /j alias for /join', () {
      final result = processor.parseCommand('/j #general');
      expect(result, isNotNull);
      expect(result?.command, 'join'); // Resolved to base command
      expect(result?.arguments, ['#general']);
    });

    test('parseCommand should correctly parse /msg command', () {
      final result = processor.parseCommand('/msg alice hello there');
      expect(result, isNotNull);
      expect(result?.command, 'msg');
      expect(result?.arguments, ['alice', 'hello', 'there']);
    });

    test('parseCommand should correctly parse /m alias for /msg', () {
      final result = processor.parseCommand('/m bob hi');
      expect(result, isNotNull);
      expect(result?.command, 'msg');
      expect(result?.arguments, ['bob', 'hi']);
    });

    test('parseCommand should correctly parse /who command', () {
      final result = processor.parseCommand('/who');
      expect(result, isNotNull);
      expect(result?.command, 'who');
      expect(result?.arguments, isEmpty);
    });

    test('parseCommand should correctly parse /w alias for /who', () {
      final result = processor.parseCommand('/w');
      expect(result, isNotNull);
      expect(result?.command, 'who');
      expect(result?.arguments, isEmpty);
    });

    test('parseCommand should correctly parse /block command', () {
      final result = processor.parseCommand('/block alice');
      expect(result, isNotNull);
      expect(result?.command, 'block');
      expect(result?.arguments, ['alice']);
    });

    test('parseCommand should correctly parse /ignore alias for /block', () {
      final result = processor.parseCommand('/ignore bob');
      expect(result, isNotNull);
      expect(result?.command, 'block');
      expect(result?.arguments, ['bob']);
    });

    test('parseCommand should correctly parse /unblock command', () {
      final result = processor.parseCommand('/unblock alice');
      expect(result, isNotNull);
      expect(result?.command, 'unblock');
      expect(result?.arguments, ['alice']);
    });

    test('parseCommand should correctly parse /help command', () {
      final result = processor.parseCommand('/help');
      expect(result, isNotNull);
      expect(result?.command, 'help');
      expect(result?.arguments, isEmpty);
    });

    test('parseCommand should handle commands with @ prefix on nicknames', () {
      final result = processor.parseCommand('/msg @alice hello');
      expect(result, isNotNull);
      expect(result?.command, 'msg');
      expect(result?.arguments, ['@alice', 'hello']);
    });

    test('parseCommand should return null for invalid command format', () {
      expect(processor.parseCommand(''), null);
      expect(processor.parseCommand('hello'), null);
      expect(processor.parseCommand('/'), null);
    });

    test('parseCommand should normalize command names to lowercase', () {
      final result1 = processor.parseCommand('/JOIN #general');
      final result2 = processor.parseCommand('/Join #general');
      final result3 = processor.parseCommand('/join #general');

      expect(result1?.command, 'join');
      expect(result2?.command, 'join');
      expect(result3?.command, 'join');
    });

    test('ParsedCommand restArguments should return joined arguments', () {
      final result =
          processor.parseCommand('/msg alice hello there how are you');
      expect(result?.restArguments, 'hello there how are you');
    });

    test('ParsedCommand firstArgument should return first argument', () {
      final result = processor.parseCommand('/msg alice hello');
      expect(result?.firstArgument, 'alice');
    });
  });

  group('CommandProcessor - Command Suggestions', () {
    late CommandProcessor processor;

    setUp(() {
      processor = CommandProcessor();
    });

    test('getCommandSuggestions should return all commands', () {
      final suggestions = processor.getCommandSuggestions();
      expect(suggestions.length, greaterThan(0));

      final commands = suggestions.map((s) => s.command).toList();
      expect(commands, contains('/join'));
      expect(commands, contains('/msg'));
      expect(commands, contains('/who'));
      expect(commands, contains('/block'));
      expect(commands, contains('/unblock'));
      expect(commands, contains('/help'));
    });

    test('getFilteredSuggestions should filter by partial input', () {
      final suggestions = processor.getFilteredSuggestions('/j');
      expect(suggestions.length, greaterThan(0));

      final commands = suggestions.map((s) => s.command).toList();
      expect(commands, contains('/join'));
    });

    test('getFilteredSuggestions should return empty for non-command input',
        () {
      final suggestions = processor.getFilteredSuggestions('hello');
      expect(suggestions, isEmpty);
    });

    test('CommandSuggestion should match by command name', () {
      final suggestions = processor.getCommandSuggestions();
      final joinCmd = suggestions.firstWhere((s) => s.command == '/join');
      expect(joinCmd.matches('/join'), true);
      expect(joinCmd.matches('/j'), true);
      expect(joinCmd.matches('/who'), false);
    });
  });

  group('CommandProcessor - /join Command', () {
    late CommandProcessor processor;
    late MockBluetoothMeshService meshService;
    late String myPeerID = 'test-peer-123';

    setUp(() {
      processor = CommandProcessor();
      meshService = MockBluetoothMeshService();
    });

    test('/join with channel should succeed', () {
      final result =
          processor.processCommand('/join #general', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('joined channel #general'));
    });

    test('/join without # prefix should add it', () {
      final result =
          processor.processCommand('/join general', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('joined channel #general'));
    });

    test('/join without channel argument should fail', () {
      final result = processor.processCommand('/join', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('usage: /join <channel>'));
    });

    test('/j alias should work same as /join', () {
      final result =
          processor.processCommand('/j #test', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('joined channel #test'));
    });
  });

  group('CommandProcessor - /msg Command', () {
    late CommandProcessor processor;
    late MockBluetoothMeshService meshService;
    late String myPeerID = 'test-peer-123';

    setUp(() {
      processor = CommandProcessor();
      meshService = MockBluetoothMeshService();

      // Add a test peer
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer-alice-id',
        name: 'Alice',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    test('/msg with peer and message should succeed', () {
      final result =
          processor.processCommand('/msg Alice hello', meshService, myPeerID);
      expect(result.success, true);
    });

    test('/msg with @ prefix on nickname should work', () {
      final result =
          processor.processCommand('/msg @Alice hello', meshService, myPeerID);
      expect(result.success, true);
    });

    test('/msg without message should return success info', () {
      final result =
          processor.processCommand('/msg Alice', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('private chat with Alice started'));
    });

    test('/msg with unknown peer should fail', () {
      final result = processor.processCommand(
          '/msg UnknownUser hello', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('not found'));
    });

    test('/msg without peer should show usage', () {
      final result = processor.processCommand('/msg', meshService, myPeerID);
      expect(result.success, false);
      expect(
          result.systemMessage, contains('usage: /msg <nickname> [message]'));
    });

    test('/m alias should work same as /msg', () {
      final result =
          processor.processCommand('/m Alice hi there', meshService, myPeerID);
      expect(result.success, true);
    });
  });

  group('CommandProcessor - /who Command', () {
    late CommandProcessor processor;
    late MockBluetoothMeshService meshService;
    late String myPeerID = 'test-peer-123';

    setUp(() {
      processor = CommandProcessor();
      meshService = MockBluetoothMeshService();

      // Add some test peers
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer-alice-id',
        name: 'Alice',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));

      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer-bob-id',
        name: 'Bob',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    test('/who should show online peers', () {
      final result = processor.processCommand('/who', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('online users'));
      expect(result.systemMessage, contains('Alice'));
      expect(result.systemMessage, contains('Bob'));
    });

    test('/who with no peers should show empty message', () {
      final emptyMesh = MockBluetoothMeshService();
      final result = processor.processCommand('/who', emptyMesh, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('no one else is around'));
    });

    test('/w alias should work same as /who', () {
      final result = processor.processCommand('/w', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('online users'));
    });
  });

  group('CommandProcessor - /block Command', () {
    late CommandProcessor processor;
    late MockBluetoothMeshService meshService;
    late String myPeerID = 'test-peer-123';

    setUp(() {
      processor = CommandProcessor();
      meshService = MockBluetoothMeshService();

      // Add a test peer
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer-alice-id',
        name: 'Alice',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    test('/block with peer should succeed', () {
      final result =
          processor.processCommand('/block Alice', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('blocked Alice'));
      expect(processor.blockedPeers, contains('peer-alice-id'));
    });

    test('/block with @ prefix should work', () {
      final result =
          processor.processCommand('/block @Alice', meshService, myPeerID);
      expect(result.success, true);
      expect(processor.blockedPeers, contains('peer-alice-id'));
    });

    test('/block without arguments should list blocked users', () {
      processor.processCommand('/block Alice', meshService, myPeerID);
      final result = processor.processCommand('/block', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('blocked users'));
    });

    test('/block with no blocked users should show empty message', () {
      final result = processor.processCommand('/block', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('no users blocked'));
    });

    test('/block with unknown peer should fail', () {
      final result =
          processor.processCommand('/block UnknownUser', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('not found'));
    });

    test('/ignore alias should work same as /block', () {
      final result =
          processor.processCommand('/ignore Alice', meshService, myPeerID);
      expect(result.success, true);
      expect(processor.blockedPeers, contains('peer-alice-id'));
    });
  });

  group('CommandProcessor - /unblock Command', () {
    late CommandProcessor processor;
    late MockBluetoothMeshService meshService;
    late String myPeerID = 'test-peer-123';

    setUp(() {
      processor = CommandProcessor();
      meshService = MockBluetoothMeshService();

      // Add a test peer
      meshService.peerManager.addPeer(PeerInfo(
        id: 'peer-alice-id',
        name: 'Alice',
        isConnected: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    test('/unblock should succeed', () {
      // First block the peer
      processor.processCommand('/block Alice', meshService, myPeerID);
      expect(processor.blockedPeers, contains('peer-alice-id'));

      // Then unblock
      final result =
          processor.processCommand('/unblock Alice', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('unblocked Alice'));
      expect(processor.blockedPeers, isNot(contains('peer-alice-id')));
    });

    test('/unblock with @ prefix should work', () {
      // First block
      processor.processCommand('/block Alice', meshService, myPeerID);
      expect(processor.blockedPeers, contains('peer-alice-id'));

      // Then unblock
      final result =
          processor.processCommand('/unblock @Alice', meshService, myPeerID);
      expect(result.success, true);
      expect(processor.blockedPeers, isNot(contains('peer-alice-id')));
    });

    test('/unblock without arguments should show usage', () {
      final result =
          processor.processCommand('/unblock', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('usage: /unblock <nickname>'));
    });

    test('/unblock unknown peer should fail', () {
      final result = processor.processCommand(
          '/unblock UnknownUser', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('not found'));
    });

    test('/unblock non-blocked peer should fail', () {
      final result =
          processor.processCommand('/unblock Alice', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('is not blocked'));
    });

    test('/unignore alias should work same as /unblock', () {
      // Block first
      processor.processCommand('/block Alice', meshService, myPeerID);
      expect(processor.blockedPeers, contains('peer-alice-id'));

      // Then unblock with alias
      final result =
          processor.processCommand('/unignore Alice', meshService, myPeerID);
      expect(result.success, true);
      expect(processor.blockedPeers, isNot(contains('peer-alice-id')));
    });
  });

  group('CommandProcessor - /help Command', () {
    late CommandProcessor processor;
    late MockBluetoothMeshService meshService;
    late String myPeerID = 'test-peer-123';

    setUp(() {
      processor = CommandProcessor();
      meshService = MockBluetoothMeshService();
    });

    test('/help should show all commands', () {
      final result = processor.processCommand('/help', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('Available commands'));
      expect(result.systemMessage, contains('/join'));
      expect(result.systemMessage, contains('/msg'));
      expect(result.systemMessage, contains('/who'));
      expect(result.systemMessage, contains('/block'));
      expect(result.systemMessage, contains('/unblock'));
    });

    test('/h alias should work same as /help', () {
      final result = processor.processCommand('/h', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('Available commands'));
    });

    test('/? alias should work same as /help', () {
      final result = processor.processCommand('/?', meshService, myPeerID);
      expect(result.success, true);
      expect(result.systemMessage, contains('Available commands'));
    });
  });

  group('CommandProcessor - Unknown and other commands', () {
    late CommandProcessor processor;
    late MockBluetoothMeshService meshService;
    late String myPeerID = 'test-peer-123';

    setUp(() {
      processor = CommandProcessor();
      meshService = MockBluetoothMeshService();
    });

    test('unknown command should fail', () {
      final result =
          processor.processCommand('/unknown', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('unknown command'));
      expect(result.systemMessage, contains('/help'));
    });

    test('invalid command format should fail', () {
      final result = processor.processCommand('invalid', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('invalid command format'));
    });

    // Commands present in Android but not implemented in Flutter should be handled
    // as unknown commands here. We verify behavior for /leave, /clear, /wipe.

    test('/leave should be unknown and return guidance', () {
      final result = processor.processCommand('/leave', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('unknown command'));
    });

    test('/clear should be unknown and return guidance', () {
      final result = processor.processCommand('/clear', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('unknown command'));
    });

    test('/wipe should be unknown and return guidance', () {
      final result = processor.processCommand('/wipe', meshService, myPeerID);
      expect(result.success, false);
      expect(result.systemMessage, contains('unknown command'));
    });
  });

  group('CommandProcessor - CommandResult and CommandSuggestion helpers', () {
    test('CommandResult.success should create success result', () {
      final result = CommandResult.success(systemMessage: 'Test message');
      expect(result.success, true);
      expect(result.systemMessage, 'Test message');
      expect(result.error, isNull);
    });

    test('CommandResult.failure should create failure result', () {
      final result = CommandResult.failure(
        systemMessage: 'Error message',
        error: 'Detailed error',
      );
      expect(result.success, false);
      expect(result.systemMessage, 'Error message');
      expect(result.error, 'Detailed error');
    });

    test('CommandResult equality should work correctly', () {
      final result1 = CommandResult.success(systemMessage: 'Test');
      final result2 = CommandResult.success(systemMessage: 'Test');
      final result3 = CommandResult.success(systemMessage: 'Different');

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('CommandSuggestion should match command and aliases', () {
      final suggestion = CommandSuggestion(
        command: '/join',
        aliases: ['/j'],
        description: 'Join a channel',
      );

      expect(suggestion.matches('/join'), true);
      expect(suggestion.matches('/j'), true);
      expect(suggestion.matches('/who'), false);
    });

    test('CommandSuggestion equality should work correctly', () {
      final suggestion1 = CommandSuggestion(
        command: '/join',
        aliases: ['/j'],
        description: 'Join a channel',
      );

      final suggestion2 = CommandSuggestion(
        command: '/join',
        aliases: ['/j'],
        description: 'Join a channel',
      );

      final suggestion3 = CommandSuggestion(
        command: '/join',
        aliases: ['/j'],
        description: 'Different description',
      );

      expect(suggestion1, equals(suggestion2));
      expect(suggestion1, isNot(equals(suggestion3)));
    });
  });
}
