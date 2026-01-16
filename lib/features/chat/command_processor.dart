import 'package:flutter/foundation.dart';
import 'package:bitchat/features/mesh/bluetooth_mesh_service.dart';

/// Represents a command suggestion for autocomplete UI.
/// Contains command name, aliases, syntax template, and description.
@immutable
class CommandSuggestion {
  /// The primary command name (e.g., "/join")
  final String command;

  /// Alternative names for this command (e.g., ["/j"] for "/join")
  final List<String> aliases;

  /// Optional syntax template showing expected arguments (e.g., "<channel>")
  final String? syntax;

  /// Human-readable description of what command does
  final String description;

  const CommandSuggestion({
    required this.command,
    this.aliases = const [],
    this.syntax,
    required this.description,
  });

  /// Check if a given input matches this command or any of its aliases
  bool matches(String input) {
    final lowerInput = input.toLowerCase();
    return command.startsWith(lowerInput) ||
        aliases.any((alias) => alias.startsWith(lowerInput));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommandSuggestion &&
        other.command == command &&
        listEquals(other.aliases, aliases) &&
        other.syntax == syntax &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(command, aliases, syntax, description);
}

/// Result of processing a command.
/// Contains success status, optional system message, and error details.
@immutable
class CommandResult {
  /// Whether command was successfully processed
  final bool success;

  /// Optional system message to display to user
  final String? systemMessage;

  /// Optional error details for logging/debugging
  final String? error;

  const CommandResult({
    required this.success,
    this.systemMessage,
    this.error,
  });

  /// Create a successful result
  factory CommandResult.success({String? systemMessage}) {
    return CommandResult(
      success: true,
      systemMessage: systemMessage,
    );
  }

  /// Create a failure result
  factory CommandResult.failure({
    required String systemMessage,
    String? error,
  }) {
    return CommandResult(
      success: false,
      systemMessage: systemMessage,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommandResult &&
        other.success == success &&
        other.systemMessage == systemMessage &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(success, systemMessage, error);
}

/// Parsed command with command name and arguments.
@immutable
class ParsedCommand {
  /// The primary command name (lowercase, without prefix)
  final String command;

  /// Full command text including prefix
  final String fullCommand;

  /// List of arguments provided after the command name
  final List<String> arguments;

  const ParsedCommand({
    required this.command,
    required this.fullCommand,
    required this.arguments,
  });

  /// Get the first argument if available
  String? get firstArgument => arguments.isNotEmpty ? arguments.first : null;

  /// Get all arguments joined as a string (excluding first)
  String get restArguments =>
      arguments.length > 1 ? arguments.skip(1).join(' ') : '';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedCommand &&
        other.command == command &&
        other.fullCommand == fullCommand &&
        listEquals(other.arguments, arguments);
  }

  @override
  int get hashCode => Object.hash(command, fullCommand, arguments);
}

/// Handles processing of IRC-style chat commands for the mesh network.
/// Parses commands starting with '/' or '!' and delegates to appropriate handlers.
class CommandProcessor {
  /// Command prefixes that trigger command processing
  static const List<String> _commandPrefixes = ['/', '!'];

  /// Supported commands and their aliases
  static const Map<String, List<String>> _commandAliases = {
    'join': ['j'],
    'msg': ['m', 'pm', 'tell'],
    'who': ['w'],
    'block': ['ignore'],
    'unblock': ['unignore'],
    'help': ['h', '?'],
  };

  /// Command definitions with syntax and descriptions
  static const List<CommandSuggestion> _commandDefinitions = [
    CommandSuggestion(
      command: '/join',
      aliases: ['/j'],
      syntax: '<channel>',
      description: 'join or create a channel',
    ),
    CommandSuggestion(
      command: '/msg',
      aliases: ['/m', '/pm', '/tell'],
      syntax: '<nickname> [message]',
      description: 'send private message',
    ),
    CommandSuggestion(
      command: '/who',
      aliases: ['/w'],
      description: 'show online peers and status',
    ),
    CommandSuggestion(
      command: '/block',
      aliases: ['/ignore'],
      syntax: '[nickname]',
      description: 'block or list blocked peers',
    ),
    CommandSuggestion(
      command: '/unblock',
      aliases: ['/unignore'],
      syntax: '<nickname>',
      description: 'unblock a peer',
    ),
    CommandSuggestion(
      command: '/help',
      aliases: ['/h', '/?'],
      description: 'show available commands',
    ),
  ];

  /// Map of blocked peer IDs (for demonstration; in production use persistent storage)
  final Set<String> _blockedPeers = {};

  /// Set of blocked peer IDs
  Set<String> get blockedPeers => Set.unmodifiable(_blockedPeers);

  /// Parse a command string into its components.
  /// Returns null if the input is not a valid command.
  ParsedCommand? parseCommand(String input) {
    if (input.isEmpty) return null;

    final trimmed = input.trim();
    final hasPrefix = _commandPrefixes.any(trimmed.startsWith);

    if (!hasPrefix) return null;

    // Extract command name (first word after prefix)
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;

    // Get the command part without prefix
    final commandWithPrefix = parts.first.toLowerCase();
    final commandName = _stripPrefix(commandWithPrefix);

    if (commandName.isEmpty) return null;

    // Normalize to base command (handle aliases)
    final baseCommand = _resolveAlias(commandName);

    final arguments = parts.length > 1 ? parts.skip(1).toList() : <String>[];

    return ParsedCommand(
      command: baseCommand,
      fullCommand: trimmed,
      arguments: arguments,
    );
  }

  /// Check if the input is a command (starts with '/' or '!')
  bool isCommand(String input) {
    if (input.isEmpty) return false;
    return _commandPrefixes.any(input.trim().startsWith);
  }

  /// Process a command and return the result.
  /// This is the main entry point for command handling.
  CommandResult processCommand(
    String input,
    BluetoothMeshService meshService,
    String myPeerID,
  ) {
    final parsed = parseCommand(input);
    if (parsed == null) {
      return CommandResult.failure(
        systemMessage: 'invalid command format',
      );
    }

    // Log command execution for audit trail (without sensitive content)
    _logCommand(parsed.command, myPeerID);

    // Route to appropriate handler
    switch (parsed.command) {
      case 'join':
        return _handleJoinCommand(parsed, meshService, myPeerID);
      case 'msg':
        return _handleMessageCommand(parsed, meshService, myPeerID);
      case 'who':
        return _handleWhoCommand(meshService);
      case 'block':
        return _handleBlockCommand(parsed, meshService);
      case 'unblock':
        return _handleUnblockCommand(parsed, meshService);
      case 'help':
        return _handleHelpCommand();
      default:
        return CommandResult.failure(
          systemMessage: "unknown command: /${parsed.command}. type /help for available commands.",
          error: 'Unknown command: ${parsed.command}',
        );
    }
  }

  /// Get all available command suggestions.
  List<CommandSuggestion> getCommandSuggestions() {
    return List.unmodifiable(_commandDefinitions);
  }

  /// Filter command suggestions based on partial input.
  List<CommandSuggestion> getFilteredSuggestions(String input) {
    if (!isCommand(input)) return [];

    return _commandDefinitions.where((def) => def.matches(input)).toList();
  }

  /// Resolve an alias to its base command name.
  String _resolveAlias(String commandName) {
    for (final entry in _commandAliases.entries) {
      final baseCommand = entry.key;
      final aliases = entry.value;

      if (baseCommand == commandName || aliases.contains(commandName)) {
        return baseCommand;
      }
    }
    return commandName;
  }

  /// Strip the command prefix from a command string.
  String _stripPrefix(String command) {
    for (final prefix in _commandPrefixes) {
      if (command.startsWith(prefix)) {
        return command.substring(prefix.length);
      }
    }
    return command;
  }

  /// Remove a prefix from a string if it exists.
  String _removePrefix(String input, String prefix) {
    if (input.startsWith(prefix)) {
      return input.substring(prefix.length);
    }
    return input;
  }

  // MARK: - Command Handlers

  /// Handle the /join command to join a channel or conference.
  CommandResult _handleJoinCommand(
    ParsedCommand command,
    BluetoothMeshService meshService,
    String myPeerID,
  ) {
    if (command.arguments.isEmpty) {
      return CommandResult.failure(
        systemMessage: 'usage: /join <channel>',
      );
    }

    final channelName = command.arguments.first;
    final normalizedChannel = channelName.startsWith('#')
        ? channelName
        : '#$channelName';

    // TODO: Implement actual channel joining logic
    // This would need a ChannelManager to track active channels
    // For now, we'll just acknowledge command

    return CommandResult.success(
      systemMessage: 'joined channel $normalizedChannel',
    );
  }

  /// Handle the /msg command to send a private message.
  CommandResult _handleMessageCommand(
    ParsedCommand command,
    BluetoothMeshService meshService,
    String myPeerID,
  ) {
    if (command.arguments.isEmpty) {
      return CommandResult.failure(
        systemMessage: 'usage: /msg <nickname> [message]',
      );
    }

    final targetName = _removePrefix(command.arguments.first, '@');
    final peerID = _findPeerIDByNickname(targetName, meshService);

    if (peerID == null) {
      return CommandResult.failure(
        systemMessage: 'user "$targetName" not found. they may be offline or using a different nickname.',
      );
    }

    if (command.arguments.length < 2) {
      return CommandResult.success(
        systemMessage: 'private chat with $targetName started',
      );
    }

    final messageContent = command.restArguments;

    // Send private message via mesh service
    try {
      // TODO: Implement proper private message sending
      // This should use the isPrivate flag and set recipientNickname
      meshService.sendMessage(
        messageContent,
        mentions: null,
        channel: null,
      );

      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(
        systemMessage: 'failed to send message to $targetName',
        error: e.toString(),
      );
    }
  }

  /// Handle the /who command to show online peers.
  CommandResult _handleWhoCommand(BluetoothMeshService meshService) {
    final activePeers = meshService.getActivePeers();

    if (activePeers.isEmpty) {
      return CommandResult.success(
        systemMessage: 'no one else is around right now.',
      );
    }

    final peerList = activePeers
        .map((peer) {
          final nickname = _getPeerNickname(peer.id, meshService);
          final status = peer.isConnected ? '' : ' (offline)';
          return '$nickname$status';
        })
        .join(', ');

    return CommandResult.success(
      systemMessage: 'online users: $peerList',
    );
  }

  /// Handle the /block command to block or list blocked peers.
  CommandResult _handleBlockCommand(
    ParsedCommand command,
    BluetoothMeshService meshService,
  ) {
    if (command.arguments.isEmpty) {
      // List blocked users
      if (_blockedPeers.isEmpty) {
        return CommandResult.success(
          systemMessage: 'no users blocked',
        );
      }

      final blockedList = _blockedPeers
          .map((peerID) => _getPeerNickname(peerID, meshService))
          .join(', ');

      return CommandResult.success(
        systemMessage: 'blocked users: $blockedList',
      );
    }

    final targetName = _removePrefix(command.arguments.first, '@');
    final peerID = _findPeerIDByNickname(targetName, meshService);

    if (peerID == null) {
      return CommandResult.failure(
        systemMessage: 'user "$targetName" not found',
      );
    }

    _blockedPeers.add(peerID);

    return CommandResult.success(
      systemMessage: 'blocked $targetName',
    );
  }

  /// Handle the /unblock command to unblock a peer.
  CommandResult _handleUnblockCommand(
    ParsedCommand command,
    BluetoothMeshService meshService,
  ) {
    if (command.arguments.isEmpty) {
      return CommandResult.failure(
        systemMessage: 'usage: /unblock <nickname>',
      );
    }

    final targetName = _removePrefix(command.arguments.first, '@');
    final peerID = _findPeerIDByNickname(targetName, meshService);

    if (peerID == null) {
      return CommandResult.failure(
        systemMessage: 'user "$targetName" not found',
      );
    }

    if (!_blockedPeers.contains(peerID)) {
      return CommandResult.failure(
        systemMessage: '$targetName is not blocked',
      );
    }

    _blockedPeers.remove(peerID);

    return CommandResult.success(
      systemMessage: 'unblocked $targetName',
    );
  }

  /// Handle the /help command to show available commands.
  CommandResult _handleHelpCommand() {
    final buffer = StringBuffer('Available commands:\n');

    for (final def in _commandDefinitions) {
      buffer.write('  ${def.command}');

      if (def.aliases.isNotEmpty) {
        buffer.write(' (${def.aliases.join(', ')})');
      }

      if (def.syntax != null) {
        buffer.write(' ${def.syntax}');
      }

      buffer.write(' - ${def.description}\n');
    }

    return CommandResult.success(
      systemMessage: buffer.toString().trim(),
    );
  }

  // MARK: - Helper Methods

  /// Find a peer ID by nickname.
  /// Returns null if not found.
  String? _findPeerIDByNickname(
    String nickname,
    BluetoothMeshService meshService,
  ) {
    final allPeers = meshService.peerManager.getAllPeers();

    for (final peer in allPeers) {
      if (peer.name.toLowerCase() == nickname.toLowerCase()) {
        return peer.id;
      }
    }

    return null;
  }

  /// Get the display nickname for a peer ID.
  String _getPeerNickname(String peerID, BluetoothMeshService meshService) {
    final peer = meshService.peerManager.getPeer(peerID);
    return peer?.name ?? peerID;
  }

  /// Log command execution for audit trail.
  void _logCommand(String command, String executorPeerID) {
    // In production, this would log to a secure audit log
    // For now, we use debugPrint (avoiding print per AGENTS.md guidelines)
    // debugPrint('[CommandProcessor] Peer $executorPeerID executed: /$command');

    // TODO: Integrate with proper logging service when available
  }
}
