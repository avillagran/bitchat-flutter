import 'dart:convert';

class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      };

  static NostrEvent? fromJsonString(String jsonString) {
    try {
      final map = json.decode(jsonString) as Map<String, dynamic>;
      return NostrEvent(
        id: map['id'] as String,
        pubkey: map['pubkey'] as String,
        createdAt: (map['created_at'] as num).toInt(),
        kind: (map['kind'] as num).toInt(),
        tags: (map['tags'] as List)
            .map<List<String>>(
                (e) => (e as List).map((v) => v.toString()).toList())
            .toList(),
        content: map['content'] as String,
        sig: map['sig'] as String,
      );
    } catch (e) {
      return null;
    }
  }
}
