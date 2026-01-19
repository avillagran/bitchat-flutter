import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Enum for peer state or transport type, extendable for BLE, TCP, WebRTC, etc.
enum TransportType {
  unknown,
  bluetooth,
  wifiDirect,
  internet,
  relay,
}

/// Model representing all information for a mesh peer.
/// Fields are mapped for full Android parity; new fields may be added as needed.
@immutable
class PeerInfo {
  /// Unique, stable peer identifier
  final String id;

  /// Display name or nickname of the peer
  final String name;

  /// Peer Noise public key (used for encrypted sessions)
  final Uint8List? noisePublicKey;

  /// Peer signing public key (e.g., Ed25519 for signatures, can be null)
  final Uint8List? signingPublicKey;

  /// Is this peer currently connected/active?
  final bool isConnected;

  /// Timestamp (millisecondsSinceEpoch) of last message or discovery event
  final int lastSeen;

  /// Most recently reported RSSI (signal strength); null if unknown
  final int? rssi;

  /// Transport mechanism (Bluetooth, WiFi, etc.)
  final TransportType transport;

  /// True if the peer's name/nickname has been IRL-verified (sig or handshake)
  final bool isVerifiedName;

  const PeerInfo({
    required this.id,
    required this.name,
    this.noisePublicKey,
    this.signingPublicKey,
    required this.isConnected,
    required this.lastSeen,
    this.rssi,
    this.transport = TransportType.unknown,
    this.isVerifiedName = false,
  });

  PeerInfo copyWith({
    String? id,
    String? name,
    Uint8List? noisePublicKey,
    Uint8List? signingPublicKey,
    bool? isConnected,
    int? lastSeen,
    int? rssi,
    TransportType? transport,
    bool? isVerifiedName,
  }) {
    return PeerInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      noisePublicKey: noisePublicKey ?? this.noisePublicKey,
      signingPublicKey: signingPublicKey ?? this.signingPublicKey,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
      rssi: rssi ?? this.rssi,
      transport: transport ?? this.transport,
      isVerifiedName: isVerifiedName ?? this.isVerifiedName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PeerInfo) return false;
    return id == other.id &&
        name == other.name &&
        isConnected == other.isConnected &&
        lastSeen == other.lastSeen &&
        rssi == other.rssi &&
        transport == other.transport &&
        isVerifiedName == other.isVerifiedName &&
        _bytesEqual(noisePublicKey, other.noisePublicKey) &&
        _bytesEqual(signingPublicKey, other.signingPublicKey);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        isConnected,
        lastSeen,
        rssi,
        transport,
        isVerifiedName,
        noisePublicKey != null ? Object.hashAll(noisePublicKey!) : null,
        signingPublicKey != null ? Object.hashAll(signingPublicKey!) : null,
      );

  /// Helper to compare Uint8List byte-by-byte
  static bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() =>
      'PeerInfo(id: $id, name: $name, connected: $isConnected)';
}

/// Interface for managing mesh peers. ChangeNotifier for Provider/Riverpod.
/// Storage hooks and deep-integration points are marked for future use.
class PeerManager extends ChangeNotifier {
  /// Internal map of peerID to PeerInfo.
  final Map<String, PeerInfo> _peers = {};

  /// Add or update a peer entry.
  /// If the peer exists, updates its info; otherwise adds new.
  void addPeer(PeerInfo peer) {
    _peers[peer.id] = peer;
    // TODO: Hook for persistent storage/provider sync if needed.
    notifyListeners();
  }

  /// Remove a peer by ID.
  /// Notifies listeners. Can be extended to support removal reason.
  void removePeer(String id) {
    if (_peers.remove(id) != null) {
      // TODO: Hook for persistent storage/provider sync if needed.
      notifyListeners();
    }
  }

  /// Update fields of an existing peer.
  /// Returns true if update was successful.
  bool updatePeer(
    String id, {
    String? name,
    Uint8List? noisePublicKey,
    Uint8List? signingPublicKey,
    bool? isConnected,
    int? lastSeen,
    int? rssi,
    TransportType? transport,
    bool? isVerifiedName,
  }) {
    final peer = _peers[id];
    if (peer == null) return false;
    _peers[id] = peer.copyWith(
      name: name,
      noisePublicKey: noisePublicKey,
      signingPublicKey: signingPublicKey,
      isConnected: isConnected,
      lastSeen: lastSeen,
      rssi: rssi,
      transport: transport,
      isVerifiedName: isVerifiedName,
    );
    // TODO: Hook for persistent storage/provider sync if needed.
    notifyListeners();
    return true;
  }

  /// Get details for a single peer (by id).
  PeerInfo? getPeer(String id) => _peers[id];

  /// Return an immutable copy of all peers.
  List<PeerInfo> getAllPeers() => List.unmodifiable(_peers.values);

  /// (Optional) Expose a stream/listenable for riverpod or widget consumption
  /// (already supported via ChangeNotifier; can add custom event streams here)

  // TODO: Implement serialization, sync with persistent storage, or network
  //       as required for future expansion/testability.
}
