import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:bitchat/data/models/bitchat_message.dart';

/// Message storage service for persisting chat messages with Hive.
///
/// Provides persistence for:
/// - Public mesh messages
/// - Private messages by peer
/// - Channel messages
///
/// Mirrors Android AppStateStore functionality with additional disk persistence.
class MessageStorageService {
  static const String _publicMessagesBox = 'public_messages';
  static const String _privateMessagesBox = 'private_messages';
  static const String _channelMessagesBox = 'channel_messages';
  static const String _seenMessageIdsBox = 'seen_message_ids';

  static const int _maxMessagesPerContext = 500;

  Box<String>? _publicBox;
  Box<String>? _privateBox;
  Box<String>? _channelBox;
  Box<bool>? _seenIdsBox;

  bool _initialized = false;

  /// Initialize the message storage service.
  /// Must be called after Hive.initFlutter().
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _publicBox = await Hive.openBox<String>(_publicMessagesBox);
      _privateBox = await Hive.openBox<String>(_privateMessagesBox);
      _channelBox = await Hive.openBox<String>(_channelMessagesBox);
      _seenIdsBox = await Hive.openBox<bool>(_seenMessageIdsBox);
      _initialized = true;
      debugPrint('[MessageStorageService] Initialized successfully');
    } catch (e) {
      debugPrint('[MessageStorageService] Initialization failed: $e');
      rethrow;
    }
  }

  /// Check if a message has been seen before (for deduplication).
  bool hasSeenMessage(String messageId) {
    if (!_initialized || _seenIdsBox == null) return false;
    return _seenIdsBox!.containsKey(messageId);
  }

  /// Mark a message as seen.
  Future<void> markMessageSeen(String messageId) async {
    if (!_initialized || _seenIdsBox == null) return;
    await _seenIdsBox!.put(messageId, true);
  }

  // ============================================================
  // Public Messages
  // ============================================================

  /// Add a public message.
  /// Returns true if the message was added, false if it was a duplicate.
  Future<bool> addPublicMessage(BitchatMessage message) async {
    if (!_initialized || _publicBox == null) return false;

    if (hasSeenMessage(message.id)) {
      return false;
    }

    try {
      await markMessageSeen(message.id);
      final json = jsonEncode(message.toJson());
      await _publicBox!.add(json);

      // Trim old messages if needed
      await _trimBox(_publicBox!, _maxMessagesPerContext);

      return true;
    } catch (e) {
      debugPrint('[MessageStorageService] Error adding public message: $e');
      return false;
    }
  }

  /// Get all public messages.
  List<BitchatMessage> getPublicMessages() {
    if (!_initialized || _publicBox == null) return [];

    try {
      return _publicBox!.values
          .map((json) => BitchatMessage.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('[MessageStorageService] Error loading public messages: $e');
      return [];
    }
  }

  // ============================================================
  // Private Messages
  // ============================================================

  /// Add a private message for a specific peer.
  /// Returns true if the message was added, false if it was a duplicate.
  Future<bool> addPrivateMessage(String peerID, BitchatMessage message) async {
    if (!_initialized || _privateBox == null) return false;

    if (hasSeenMessage(message.id)) {
      return false;
    }

    try {
      await markMessageSeen(message.id);

      // Get existing messages for this peer
      final key = _normalizeKey(peerID);
      final existing = _getPrivateMessagesForPeer(key);
      existing.add(message);

      // Trim to max
      final trimmed = existing.length > _maxMessagesPerContext
          ? existing.sublist(existing.length - _maxMessagesPerContext)
          : existing;

      // Serialize and store
      final jsonList = trimmed.map((m) => m.toJson()).toList();
      await _privateBox!.put(key, jsonEncode(jsonList));

      return true;
    } catch (e) {
      debugPrint('[MessageStorageService] Error adding private message: $e');
      return false;
    }
  }

  /// Get private messages for a specific peer.
  List<BitchatMessage> getPrivateMessages(String peerID) {
    return _getPrivateMessagesForPeer(_normalizeKey(peerID));
  }

  /// Get all private messages grouped by peer ID.
  Map<String, List<BitchatMessage>> getAllPrivateMessages() {
    if (!_initialized || _privateBox == null) return {};

    try {
      final result = <String, List<BitchatMessage>>{};
      for (final key in _privateBox!.keys) {
        final messages = _getPrivateMessagesForPeer(key as String);
        if (messages.isNotEmpty) {
          result[key] = messages;
        }
      }
      return result;
    } catch (e) {
      debugPrint('[MessageStorageService] Error loading private messages: $e');
      return {};
    }
  }

  List<BitchatMessage> _getPrivateMessagesForPeer(String key) {
    if (!_initialized || _privateBox == null) return [];

    try {
      final json = _privateBox!.get(key);
      if (json == null) return [];

      final list = jsonDecode(json) as List<dynamic>;
      return list.map((m) => BitchatMessage.fromJson(m)).toList();
    } catch (e) {
      debugPrint(
          '[MessageStorageService] Error parsing private messages for $key: $e');
      return [];
    }
  }

  // ============================================================
  // Channel Messages
  // ============================================================

  /// Add a channel message.
  /// Returns true if the message was added, false if it was a duplicate.
  Future<bool> addChannelMessage(String channel, BitchatMessage message) async {
    if (!_initialized || _channelBox == null) return false;

    if (hasSeenMessage(message.id)) {
      return false;
    }

    try {
      await markMessageSeen(message.id);

      // Get existing messages for this channel
      final key = _normalizeKey(channel);
      final existing = _getChannelMessagesForChannel(key);
      existing.add(message);

      // Trim to max
      final trimmed = existing.length > _maxMessagesPerContext
          ? existing.sublist(existing.length - _maxMessagesPerContext)
          : existing;

      // Serialize and store
      final jsonList = trimmed.map((m) => m.toJson()).toList();
      await _channelBox!.put(key, jsonEncode(jsonList));

      return true;
    } catch (e) {
      debugPrint('[MessageStorageService] Error adding channel message: $e');
      return false;
    }
  }

  /// Get channel messages for a specific channel.
  List<BitchatMessage> getChannelMessages(String channel) {
    return _getChannelMessagesForChannel(_normalizeKey(channel));
  }

  /// Get all channel messages grouped by channel name.
  Map<String, List<BitchatMessage>> getAllChannelMessages() {
    if (!_initialized || _channelBox == null) return {};

    try {
      final result = <String, List<BitchatMessage>>{};
      for (final key in _channelBox!.keys) {
        final messages = _getChannelMessagesForChannel(key as String);
        if (messages.isNotEmpty) {
          result[key] = messages;
        }
      }
      return result;
    } catch (e) {
      debugPrint('[MessageStorageService] Error loading channel messages: $e');
      return {};
    }
  }

  List<BitchatMessage> _getChannelMessagesForChannel(String key) {
    if (!_initialized || _channelBox == null) return [];

    try {
      final json = _channelBox!.get(key);
      if (json == null) return [];

      final list = jsonDecode(json) as List<dynamic>;
      return list.map((m) => BitchatMessage.fromJson(m)).toList();
    } catch (e) {
      debugPrint(
          '[MessageStorageService] Error parsing channel messages for $key: $e');
      return [];
    }
  }

  // ============================================================
  // Message Status Updates
  // ============================================================

  /// Update delivery status for a private message.
  Future<void> updatePrivateMessageStatus(
    String messageID,
    DeliveryStatus status,
  ) async {
    if (!_initialized || _privateBox == null) return;

    try {
      for (final peerKey in _privateBox!.keys) {
        final messages = _getPrivateMessagesForPeer(peerKey as String);
        final index = messages.indexWhere((m) => m.id == messageID);

        if (index != -1) {
          // Check if we should update (don't downgrade status)
          final current = messages[index].deliveryStatus;
          if (_shouldUpdateStatus(current, status)) {
            messages[index] = messages[index].copyWith(deliveryStatus: status);
            final jsonList = messages.map((m) => m.toJson()).toList();
            await _privateBox!.put(peerKey, jsonEncode(jsonList));
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('[MessageStorageService] Error updating message status: $e');
    }
  }

  bool _shouldUpdateStatus(DeliveryStatus? current, DeliveryStatus next) {
    // Priority: sending < sent < delivered < read
    int priority(DeliveryStatus? s) {
      if (s == null) return 0;
      return s.when(
        sending: () => 1,
        sent: () => 2,
        delivered: (_, __) => 4,
        read: (_, __) => 5,
        failed: (_) => 0,
        partiallyDelivered: (_, __) => 3,
      );
    }

    return priority(next) >= priority(current);
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  String _normalizeKey(String key) => key.toLowerCase();

  Future<void> _trimBox(Box<String> box, int maxEntries) async {
    if (box.length > maxEntries) {
      final keysToDelete = box.keys.take(box.length - maxEntries).toList();
      for (final key in keysToDelete) {
        await box.delete(key);
      }
    }
  }

  /// Clear all stored messages.
  Future<void> clearAll() async {
    if (!_initialized) return;

    try {
      await _publicBox?.clear();
      await _privateBox?.clear();
      await _channelBox?.clear();
      await _seenIdsBox?.clear();
      debugPrint('[MessageStorageService] Cleared all messages');
    } catch (e) {
      debugPrint('[MessageStorageService] Error clearing messages: $e');
    }
  }

  /// Get debug information about storage state.
  String getDebugInfo() {
    if (!_initialized) return 'MessageStorageService not initialized';

    final buffer = StringBuffer();
    buffer.writeln('=== Message Storage Debug ===');
    buffer.writeln('Public messages: ${_publicBox?.length ?? 0}');
    buffer.writeln('Private conversations: ${_privateBox?.keys.length ?? 0}');
    buffer.writeln('Channels: ${_channelBox?.keys.length ?? 0}');
    buffer.writeln('Seen message IDs: ${_seenIdsBox?.length ?? 0}');
    return buffer.toString();
  }

  /// Close all boxes.
  Future<void> close() async {
    await _publicBox?.close();
    await _privateBox?.close();
    await _channelBox?.close();
    await _seenIdsBox?.close();
    _initialized = false;
  }
}
