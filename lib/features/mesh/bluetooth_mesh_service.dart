import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:bitchat/features/crypto/encryption_service.dart';
import 'package:bitchat/features/mesh/ble_manager.dart';
import 'package:bitchat/features/mesh/gatt_server_manager.dart';
import 'package:bitchat/features/mesh/gatt_client_manager.dart';
import 'package:bitchat/features/mesh/peer_manager.dart';
import 'package:bitchat/features/mesh/store_forward_manager.dart';
import 'package:bitchat/features/mesh/power_manager.dart';
import 'package:bitchat/data/models/bitchat_message.dart';
import 'package:bitchat/data/models/routed_packet.dart';
import 'package:bitchat/data/models/identity_announcement.dart';
import 'package:bitchat/protocol/packet_codec.dart';
import 'package:bitchat/core/constants.dart';
import 'package:crypto/crypto.dart';

/// Delegate interface for mesh service callbacks.
/// Mirrors Android BluetoothMeshDelegate for cross-platform parity.
abstract class BluetoothMeshDelegate {
  /// Called when a chat message is received from the mesh.
  void didReceiveMessage(BitchatMessage message);

  /// Called when the peer list is updated.
  void didUpdatePeerList(List<String> peers);

  /// Called when a peer leaves a channel.
  void didReceiveChannelLeave(String channel, String fromPeer);

  /// Called when a delivery acknowledgement is received.
  void didReceiveDeliveryAck(String messageID, String recipientPeerID);

  /// Called when a read receipt is received.
  void didReceiveReadReceipt(String messageID, String recipientPeerID);

  /// Returns the current user's nickname.
  String? getNickname();

  /// Checks if a peer is marked as favorite.
  bool isFavorite(String peerID);
}

/// Central mesh service.
/// Manages BLE services, peers, messages, and power policy.
/// Modularly wired with PeerManager, StoreForwardManager, and PowerManager for full cross-platform compatibility.
/// Provides real packet send/receive wiring via GattClientManager and GattServerManager with PacketCodec integration.
class BluetoothMeshService
    implements BluetoothConnectionManagerDelegate, GattServerDelegate {
  static const String _tag = '[BluetoothMeshService]';
  static const int _announceIntervalSeconds = 30;

  final EncryptionService _encryptionService;

  /// BLE Peripheral (GATT Server/Advertiser). Handles advertising and server duties.
  final GattServerManager _gattServerManager = GattServerManager();

  /// BLE Central (GATT Client). Handles scanning, connections, and data exchange with peers.
  final GattClientManager _gattClientManager = GattClientManager();

  /// Mesh infrastructure managers
  final PeerManager peerManager = PeerManager();
  final StoreForwardManager storeForwardManager = StoreForwardManager();
  final PowerManager powerManager = PowerManager();

  /// My unique peer identifier (derived from encryption service identity fingerprint)
  late final String myPeerID;

  /// Delegate for message callbacks to UI layer.
  BluetoothMeshDelegate? delegate;

  /// User's nickname for announcements (defaults to peer ID if not set)
  String? userNickname;

  bool _isActive = false;
  Timer? _announceTimer;
  final List<Peripheral> _connectedDevices = [];

  /// Maps protocol peer IDs to Bluetooth device UUIDs for routing
  /// Key: peer ID (e.g., "813654e4c15d2c8d")
  /// Value: device UUID (e.g., "00000000-0000-0000-0000-6e863f1beb58")
  final Map<String, String> _peerIdToDeviceUuid = {};

  BluetoothMeshService(this._encryptionService) {
    _gattClientManager.delegate = this;
    _gattServerManager.delegate = this;
    // Derive peer ID from encryption service fingerprint (first 16 hex chars)
    myPeerID = _generatePeerID();
    // Register power state listener
    powerManager.addPowerStateListener((state) {
      // Adjust announce/scan periodicity based on battery level
      if (state.isPowerSaveMode) {
        // Could implement longer intervals or reduced scan frequency
      }
    });
  }

  /// Generates a stable peer ID from the encryption service identity fingerprint.
  String _generatePeerID() {
    try {
      final fingerprint = _encryptionService.staticPublicKey;
      final digest = sha256.convert(fingerprint);
      return digest.toString().length >= 16
          ? digest.toString().substring(0, 16)
          : digest.toString().padLeft(16, '0').substring(0, 16);
    } catch (e) {
      // Fallback to random ID if encryption service not ready
      final fallback = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
      return fallback.length >= 16
          ? fallback.substring(0, 16)
          : fallback.padLeft(16, '0').substring(0, 16);
    }
  }

  /// Starts the mesh service: advertising and scanning.
  /// Returns true if both GATT server and client started successfully.
  Future<bool> start() async {
    if (_isActive) {
      return true;
    }

    try {
      // Initialize BLE manager first
      final bleInitialized = await BleManager.instance.initialize();
      if (!bleInitialized) {
        debugPrint('$_tag Failed to initialize BLE manager');
        return false;
      }

      // Wait for Bluetooth to be powered on (up to 5 seconds)
      final bleManager = BleManager.instance;

      // Check if authorization is needed (macOS requires explicit authorize() call)
      if (bleManager.state == BluetoothLowEnergyState.unauthorized) {
        debugPrint('$_tag Bluetooth unauthorized, requesting authorization...');
        try {
          if (bleManager.supportsCentral) {
            await bleManager.central.authorize();
          }
          debugPrint('$_tag Authorization requested, state: ${bleManager.state}');
        } catch (e) {
          debugPrint('$_tag Authorization request failed: $e');
        }
      }

      int attempts = 0;
      const maxAttempts = 10;
      while (bleManager.state != BluetoothLowEnergyState.poweredOn &&
          attempts < maxAttempts) {
        debugPrint(
            '$_tag Waiting for Bluetooth (state: ${bleManager.state}, attempt ${attempts + 1}/$maxAttempts)');
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (bleManager.state != BluetoothLowEnergyState.poweredOn) {
        debugPrint(
            '$_tag Bluetooth not powered on after ${maxAttempts * 500}ms');
        return false;
      }

      final sSuccess = await _gattServerManager.start();
      final cSuccess = await _gattClientManager.start();

      if (!sSuccess || !cSuccess) {
        debugPrint(
            '$_tag Failed to start managers (server: $sSuccess, client: $cSuccess)');
        return false;
      }

      // Clean managers on startup
      for (final peer in peerManager.getAllPeers()) {
        peerManager.removePeer(peer.id);
      }
      storeForwardManager.clearAll();

      _isActive = true;
      _startPeriodicAnnounce();
      // Send immediate announce on start (matches Android BluetoothMeshService.startServices)
      await _sendBroadcastAnnounce();
      debugPrint('$_tag Mesh service started successfully');
      return true;
    } catch (e) {
      debugPrint('$_tag Failed to start mesh service: $e');
      return false;
    }
  }

  /// Stops the mesh service and cleans up resources.
  void stop() {
    if (!_isActive) {
      return;
    }

    _isActive = false;
    _announceTimer?.cancel();
    _announceTimer = null;
    _gattServerManager.stop();
    _gattClientManager.stop();
    _connectedDevices.clear();
    debugPrint('$_tag Mesh service stopped');
  }

  void _startPeriodicAnnounce() {
    _announceTimer = Timer.periodic(
      const Duration(seconds: _announceIntervalSeconds),
      (timer) {
        if (!_isActive) {
          timer.cancel();
          return;
        }
        _sendBroadcastAnnounce();
      },
    );
  }

  /// Sends a broadcast announcement packet to all connected peers.
  /// Enqueues the packet in store-forward manager for offline delivery.
  Future<void> _sendBroadcastAnnounce() async {
    debugPrint('$_tag *** _sendBroadcastAnnounce CALLED ***');
    debugPrint('$_tag My peer ID: $myPeerID');
    debugPrint('$_tag Active: $_isActive');

    // Use configured nickname or fallback to peer ID
    final nickname =
        userNickname?.isNotEmpty == true ? userNickname! : myPeerID;
    debugPrint('$_tag Announcing with nickname: $nickname');

    final announce = IdentityAnnouncement(
      nickname: nickname,
      noisePublicKey: _encryptionService.staticPublicKey,
      signingPublicKey: _encryptionService.signingPublicKey,
    );

    final payload = announce.encode();
    if (payload == null) {
      debugPrint('$_tag *** ANNOUNCEMENT ENCODE FAILED ***');
      return;
    }

    debugPrint('$_tag Announcement payload encoded: ${payload.length} bytes');
    debugPrint(
        '$_tag Payload hex (first 60): ${payload.take(60).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    final packet = BitchatPacket(
      version: 2, // Use v2 for Android compatibility (4-byte payload length)
      type: 0x01, // MessageType.identityAnnouncement
      ttl: AppConstants.messageTtlHops,
      senderID: _peerIDToBytes(myPeerID),
      timestamp: DateTime.now(),
      payload: payload,
    );

    debugPrint('$_tag Broadcasting IDENTITY_ANNOUNCEMENT packet');

    // Enqueue for store-forward (offline peers will receive later)
    storeForwardManager.enqueueMessage(StoreForwardMessage(
      id: "announce-${DateTime.now().millisecondsSinceEpoch}",
      payload: payload,
      destination: "mesh-broadcast",
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: StoreForwardMessageType.outbound,
    ));

    // Broadcast to all connected peers
    final sent = await broadcastPacket(packet);
    debugPrint(
        '$_tag IDENTITY_ANNOUNCEMENT broadcast complete, sent to $sent peers');
  }

  /// Sends a chat message to the mesh network.
  /// @param content - The message content
  /// @param mentions - Optional list of mentioned peer IDs
  /// @param channel - Optional channel name
  Future<void> sendMessage(
    String content, {
    List<String>? mentions,
    String? channel,
  }) async {
    debugPrint('$_tag sendMessage called: "$content" (active: $_isActive)');
    if (!_isActive) {
      debugPrint(
          '$_tag sendMessage: mesh service not active, message not sent');
      return;
    }

    // Use plain UTF-8 payload for Android compatibility
    // Android expects: payload = content.toByteArray(Charsets.UTF_8)
    final binary = Uint8List.fromList(utf8.encode(content));

    final packet = BitchatPacket(
      version: 2, // Use v2 for Android compatibility
      type: 0x02, // MessageType.message
      ttl: AppConstants.messageTtlHops,
      senderID: _peerIDToBytes(myPeerID),
      timestamp: DateTime.now(),
      payload: binary,
    );

    // Enqueue for store-forward in case of disconnection
    storeForwardManager.enqueueMessage(StoreForwardMessage(
      id: "msg-${DateTime.now().millisecondsSinceEpoch}",
      payload: binary,
      destination: channel ?? "mesh-broadcast",
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: StoreForwardMessageType.outbound,
    ));

    // Broadcast to all connected peers (signs packet internally)
    await broadcastPacket(packet);
  }

  /// Broadcasts a packet to all connected peers via GATT client.
  /// @param packet - The BitchatPacket to broadcast
  /// @return Number of peers the packet was sent to
  Future<int> broadcastPacket(BitchatPacket packet) async {
    debugPrint('$_tag broadcastPacket: START (isActive: $_isActive)');
    if (!_isActive) {
      debugPrint('$_tag broadcastPacket: not active, returning 0');
      return 0;
    }

    // Sign the packet before broadcast (matches Android's signPacketBeforeBroadcast)
    final signedPacket = await _signPacket(packet);
    final senderID = signedPacket.senderID ?? _peerIDToBytes(myPeerID);

    debugPrint(
        '$_tag broadcastPacket: encoding packet (payload: ${signedPacket.payload?.length ?? 0} bytes)');
    final encoded = PacketCodec.encode(
      signedPacket,
      senderID: senderID,
      signature: signedPacket.signature,
      isCompressed: false,
    );

    if (encoded == null) {
      debugPrint('$_tag broadcastPacket: encoding FAILED, returning 0');
      return 0;
    }
    debugPrint('$_tag broadcastPacket: encoded ${encoded.length} bytes');

    int sentCount = 0;
    final activePeers =
        peerManager.getAllPeers().where((p) => p.isConnected).toList();
    final Set<String> sentToCentrals =
        {}; // Track centrals we've already sent to

    debugPrint(
        '$_tag broadcastPacket: ${activePeers.length} active peers, ${_connectedDevices.length} connected devices, ${_gattServerManager.subscribedCount} subscribed centrals');
    debugPrint(
        '$_tag broadcastPacket: peerIdToDeviceUuid map has ${_peerIdToDeviceUuid.length} entries: $_peerIdToDeviceUuid');

    // For each active peer, try to send via the appropriate path
    for (final peer in activePeers) {
      try {
        debugPrint('$_tag broadcastPacket: trying to send to peer ${peer.id}');

        // First try GATT client path (we connected to them as central)
        final device = _findDeviceForPeer(peer.id);
        if (device != null) {
          debugPrint(
              '$_tag broadcastPacket: found device ${device.uuid} for peer ${peer.id}');
          final sent = await _gattClientManager.sendPacket(device, signedPacket);
          if (sent) {
            sentCount++;
            debugPrint(
                '$_tag broadcastPacket: sent to peer ${peer.id} via GATT client');
          } else {
            debugPrint(
                '$_tag broadcastPacket: failed to send to peer ${peer.id} via GATT client');
          }
          continue;
        }

        // Try GATT server path (they connected to us as central)
        final mappedCentralUuid = _peerIdToDeviceUuid[peer.id];
        if (mappedCentralUuid != null &&
            _gattServerManager.isCentralConnected(mappedCentralUuid)) {
          debugPrint(
              '$_tag broadcastPacket: peer ${peer.id} is connected as central $mappedCentralUuid');
          final sent = await _gattServerManager.sendToSpecificCentral(
              encoded, mappedCentralUuid);
          if (sent) {
            sentCount++;
            sentToCentrals.add(mappedCentralUuid.toLowerCase());
            debugPrint(
                '$_tag broadcastPacket: sent to peer ${peer.id} via GATT server (central $mappedCentralUuid)');
          }
          continue;
        }

        debugPrint('$_tag broadcastPacket: no route found for peer ${peer.id}');
      } catch (e) {
        debugPrint('$_tag Error sending to peer ${peer.id}: $e');
        continue;
      }
    }

    // Also send to any connected centrals we haven't already sent to (via GATT server notifications)
    if (_gattServerManager.connectedCount > 0) {
      debugPrint(
          '$_tag broadcastPacket: sending to ${_gattServerManager.connectedCount} centrals via GATT server');
      try {
        final sent = await _gattServerManager.sendDataToAllConnected(encoded);
        if (sent) {
          debugPrint(
              '$_tag Broadcast sent via GATT server to all ${_gattServerManager.connectedCount} connected centrals');
        }
      } catch (e) {
        debugPrint('$_tag Error sending to connected centrals: $e');
      }
    }

    // CRITICAL FALLBACK: Also write to all connected GATT client peripherals
    // This handles the case where Android's GATT server receives our writes
    // (Android doesn't subscribe to notifications, but accepts writes to its server)
    final clientDeviceCount = _gattClientManager.getConnectedCount();
    if (clientDeviceCount > 0) {
      debugPrint(
          '$_tag broadcastPacket: writing to $clientDeviceCount peripherals via GATT client');
      try {
        final clientSentCount =
            await _gattClientManager.broadcastPacket(signedPacket);
        if (clientSentCount > 0) {
          sentCount += clientSentCount;
          debugPrint(
              '$_tag Broadcast written to $clientSentCount peripherals via GATT client');
        }
      } catch (e) {
        debugPrint('$_tag Error writing to peripherals: $e');
      }
    }

    debugPrint('$_tag broadcastPacket: total sent to $sentCount destinations');
    return sentCount;
  }

  /// Sends a packet directly to a specific peer.
  /// @param peerID - The target peer ID
  /// @param packet - The BitchatPacket to send
  /// @return true if the packet was sent successfully
  Future<bool> sendPacketToPeer(String peerID, BitchatPacket packet) async {
    if (!_isActive) {
      return false;
    }

    final peer = peerManager.getPeer(peerID);
    if (peer == null || !peer.isConnected) {
      return false;
    }

    try {
      final device = _findDeviceForPeer(peerID);
      if (device == null) {
        return false;
      }

      // Sign the packet before sending
      final signedPacket = await _signPacket(packet);
      await _gattClientManager.sendPacket(device, signedPacket);
      return true;
    } catch (e) {
      debugPrint('$_tag Error sending packet to peer $peerID: $e');
      return false;
    }
  }

  /// Finds a Peripheral for a given peer ID.
  /// @param peerID - The peer ID to search for
  /// @return The Peripheral if found, null otherwise
  Peripheral? _findDeviceForPeer(String peerID) {
    // First check the peer ID to device UUID map
    final mappedUuid = _peerIdToDeviceUuid[peerID];
    if (mappedUuid != null) {
      final mappedUuidLower = mappedUuid.toLowerCase();
      for (final device in _connectedDevices) {
        if (device.uuid.toString().toLowerCase() == mappedUuidLower) {
          return device;
        }
      }
    }

    // Fallback: search connected devices for matching peer ID in UUID
    final peerIDStr = peerID.toLowerCase();
    for (final device in _connectedDevices) {
      final deviceUuid = device.uuid.toString().toLowerCase();
      if (deviceUuid.contains(peerIDStr)) {
        return device;
      }
    }
    return null;
  }

  /// Converts a peer ID string to bytes (8 bytes).
  /// @param peerID - The peer ID string
  /// @return 8-byte Uint8List representation
  Uint8List _peerIDToBytes(String peerID) {
    // Convert hex string to bytes directly (no hashing needed - peerID is already a hash)
    // Example: "997b76157eaf2e88" -> [0x99, 0x7b, 0x76, 0x15, 0x7e, 0xaf, 0x2e, 0x88]
    final bytes = Uint8List(8);
    for (int i = 0; i < 8 && i * 2 + 1 < peerID.length; i++) {
      final hexByte = peerID.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(hexByte, radix: 16);
    }
    return bytes;
  }

  /// Extracts peer ID from bytes.
  /// @param bytes - The bytes to extract from (8 bytes)
  /// @return The peer ID string
  String _bytesToPeerID(Uint8List bytes) {
    final truncated = bytes.sublist(0, 8);
    return truncated.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Signs a packet before broadcast.
  /// This matches Android's signPacketBeforeBroadcast() behavior.
  /// @param packet - The packet to sign
  /// @return The signed packet (with signature attached)
  Future<BitchatPacket> _signPacket(BitchatPacket packet) async {
    try {
      final senderID = packet.senderID ?? _peerIDToBytes(myPeerID);

      // Get the canonical packet data for signing (without signature, TTL=0)
      final dataForSigning = PacketCodec.encodeForSigning(
        packet,
        senderID: senderID,
        recipientID: packet.recipientID,
      );

      if (dataForSigning == null) {
        debugPrint('$_tag Failed to encode packet for signing, returning unsigned');
        return packet;
      }

      // DEBUG: Log the bytes being signed
      debugPrint('$_tag SIGNING: ${dataForSigning.length} bytes, hex: ${dataForSigning.take(40).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      debugPrint('$_tag SIGNING: version=${packet.version}, type=${packet.type}, TTL=0 (for signing)');

      // Sign the packet data using our signing key
      final signature = await _encryptionService.signData(dataForSigning);
      if (signature != null) {
        debugPrint('$_tag ✅ Signed packet type ${packet.type} (signature ${signature.length} bytes)');
        return packet.copyWith(signature: signature, senderID: senderID);
      } else {
        debugPrint('$_tag Failed to sign packet type ${packet.type}, returning unsigned');
        return packet;
      }
    } catch (e) {
      debugPrint('$_tag Error signing packet: $e, returning unsigned');
      return packet;
    }
  }

  // ---------------------------------------------------------------------------
  // BluetoothConnectionManagerDelegate implementation (GATT Client callbacks)
  // ---------------------------------------------------------------------------

  @override
  void onDeviceConnected(Peripheral device) {
    if (!_connectedDevices.contains(device)) {
      _connectedDevices.add(device);
      debugPrint('$_tag Device connected: ${device.uuid}');

      // Send immediate announce on device connection (matches Android)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_isActive) {
          _sendBroadcastAnnounce();
        }
      });
    }
  }

  @override
  void onDeviceDisconnected(Peripheral device) {
    _connectedDevices.remove(device);
    // Update peer connection status
    final peerID = _extractPeerIDFromDevice(device);
    if (peerID != null) {
      peerManager.updatePeer(
        peerID,
        isConnected: false,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
      );
    }
    debugPrint('$_tag Device disconnected: ${device.uuid}');
  }

  /// Extracts peer ID from a Peripheral.
  /// @param device - The device to extract peer ID from
  /// @return The peer ID string if extractable, null otherwise
  String? _extractPeerIDFromDevice(Peripheral device) {
    // Extract peer ID from device UUID (bluetooth_low_energy doesn't expose name)
    final uuidStr = device.uuid.toString();
    if (uuidStr.length >= 16) {
      return uuidStr.substring(0, 16);
    }
    return null;
  }

  @override
  void onPacketReceived(
    BitchatPacket packet,
    String peerID,
    Peripheral device,
  ) {
    // Extract or derive peer ID from packet
    final senderPeerID = packet.senderID != null
        ? _bytesToPeerID(packet.senderID!)
        : _extractPeerIDFromDevice(device) ?? peerID;

    // Map peer ID to device UUID for future routing (client connection)
    final deviceUuid = device.uuid.toString();
    _peerIdToDeviceUuid[senderPeerID] = deviceUuid;
    debugPrint(
        '$_tag Mapped peer $senderPeerID -> device $deviceUuid (client)');

    // Update or add peer - preserve existing nickname if already set
    final existingPeer = peerManager.getPeer(senderPeerID);
    final peerName = (existingPeer != null && existingPeer.name != existingPeer.id)
        ? existingPeer.name  // Keep existing nickname
        : senderPeerID;      // Use peerID as fallback

    peerManager.addPeer(PeerInfo(
      id: senderPeerID,
      name: peerName,
      noisePublicKey: existingPeer?.noisePublicKey,
      signingPublicKey: existingPeer?.signingPublicKey,
      isConnected: true,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
      rssi: null, // Can be extracted from device if available
      transport: TransportType.bluetooth,
      isVerifiedName: existingPeer?.isVerifiedName ?? false,
    ));

    // Process packet based on type
    _processIncomingPacket(packet, senderPeerID);

    // Optional: enqueue for store-forward delivery tracking
    // storeForwardManager.markMessageDelivered(...)
  }

  // ---------------------------------------------------------------------------
  // GattServerDelegate implementation (GATT Server callbacks)
  // ---------------------------------------------------------------------------

  @override
  void onDataReceived(Uint8List data, String deviceAddress) {
    debugPrint('$_tag ========================================');
    debugPrint('$_tag onDataReceived CALLED');
    debugPrint('$_tag Device: $deviceAddress');
    debugPrint('$_tag Data size: ${data.length} bytes');
    debugPrint('$_tag Raw bytes (first 40): ${data.take(40).toList()}');
    debugPrint('$_tag ========================================');

    if (data.isEmpty) {
      debugPrint('$_tag Data is empty, returning early');
      return;
    }

    // Decode the received data as a BitchatPacket
    debugPrint('$_tag Attempting to decode packet...');
    final packet = BitchatPacket.decode(data);
    if (packet == null) {
      debugPrint('$_tag *** DECODE FAILED *** for ${data.length} bytes');
      debugPrint(
          '$_tag Raw hex: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return;
    }

    debugPrint('$_tag *** DECODE SUCCESS ***');
    debugPrint('$_tag Packet type: 0x${packet.type.toRadixString(16)}');
    debugPrint('$_tag Packet TTL: ${packet.ttl}');
    debugPrint('$_tag Packet payload size: ${packet.payload?.length ?? 0}');

    // Extract peer ID from packet or derive from device address
    final senderPeerID = packet.senderID != null
        ? _bytesToPeerID(packet.senderID!)
        : deviceAddress.length >= 16
            ? deviceAddress.substring(0, 16)
            : deviceAddress;

    debugPrint(
        '$_tag Received packet from central $deviceAddress (sender: $senderPeerID)');

    // Map peer ID to device address for future routing (server connection)
    // deviceAddress is the central's UUID (e.g., "00000000-0000-0000-0000-5d871b953aa3")
    _peerIdToDeviceUuid[senderPeerID] = deviceAddress;
    debugPrint(
        '$_tag Mapped peer $senderPeerID -> central $deviceAddress (server)');

    // Update or add peer - preserve existing nickname if already set
    final existingPeer = peerManager.getPeer(senderPeerID);
    final peerName = (existingPeer != null && existingPeer.name != existingPeer.id)
        ? existingPeer.name  // Keep existing nickname
        : senderPeerID;      // Use peerID as fallback

    peerManager.addPeer(PeerInfo(
      id: senderPeerID,
      name: peerName,
      noisePublicKey: existingPeer?.noisePublicKey,
      signingPublicKey: existingPeer?.signingPublicKey,
      isConnected: true,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
      rssi: null,
      transport: TransportType.bluetooth,
      isVerifiedName: existingPeer?.isVerifiedName ?? false,
    ));

    // Process the packet
    debugPrint('$_tag Calling _processIncomingPacket...');
    _processIncomingPacket(packet, senderPeerID);
    debugPrint('$_tag _processIncomingPacket completed');
  }

  // ---------------------------------------------------------------------------
  // Packet Processing
  // ---------------------------------------------------------------------------

  /// Processes an incoming packet based on its type.
  /// @param packet - The packet to process
  /// @param peerID - The peer ID that sent the packet
  void _processIncomingPacket(BitchatPacket packet, String peerID) {
    debugPrint('$_tag ========================================');
    debugPrint('$_tag _processIncomingPacket CALLED');
    debugPrint(
        '$_tag Packet type: 0x${packet.type.toRadixString(16)} (${_getPacketTypeName(packet.type)})');
    debugPrint('$_tag From peer: $peerID');
    debugPrint('$_tag Payload size: ${packet.payload?.length ?? 0} bytes');
    debugPrint('$_tag Delegate is ${delegate == null ? "NULL" : "SET"}');
    debugPrint('$_tag ========================================');

    switch (packet.type) {
      case 0x01: // Identity announcement
        debugPrint('$_tag -> Routing to _processIdentityAnnouncement');
        _processIdentityAnnouncement(packet, peerID);
        break;
      case 0x02: // Chat message
        debugPrint('$_tag -> Routing to _processChatMessage');
        _processChatMessage(packet, peerID);
        break;
      case 0x03: // Delivery ACK
        debugPrint('$_tag Received delivery ACK from $peerID');
        // TODO: Update message delivery status
        break;
      case 0x04: // Read receipt
        debugPrint('$_tag Received read receipt from $peerID');
        // TODO: Update message read status
        break;
      case 0x21: // REQUEST_SYNC (GCS-based sync request from Android)
        debugPrint(
            '$_tag Received sync request from $peerID (ignoring - sync not implemented)');
        // TODO: Implement sync response when needed
        break;
      default:
        // Unknown packet type
        debugPrint(
            '$_tag *** UNKNOWN PACKET TYPE: 0x${packet.type.toRadixString(16)} ***');
        debugPrint(
            '$_tag Payload preview: ${packet.payload?.take(50).toList()}');
        break;
    }
  }

  /// Helper to get human-readable packet type name
  String _getPacketTypeName(int type) {
    switch (type) {
      case 0x01:
        return 'IDENTITY_ANNOUNCEMENT';
      case 0x02:
        return 'CHAT_MESSAGE';
      case 0x03:
        return 'DELIVERY_ACK';
      case 0x04:
        return 'READ_RECEIPT';
      case 0x05:
        return 'NOISE_HANDSHAKE';
      case 0x06:
        return 'PRIVATE_MESSAGE';
      case 0x10:
        return 'FILE_OFFER';
      case 0x11:
        return 'FILE_ACCEPT';
      case 0x12:
        return 'FILE_CHUNK';
      case 0x13:
        return 'FILE_COMPLETE';
      case 0x20:
        return 'FRAGMENT';
      case 0x21:
        return 'REQUEST_SYNC';
      case 0x30:
        return 'CHANNEL_JOIN';
      case 0x31:
        return 'CHANNEL_LEAVE';
      default:
        return 'UNKNOWN($type)';
    }
  }

  /// Processes an identity announcement packet.
  /// @param packet - The packet containing the announcement
  /// @param peerID - The peer ID that sent the announcement
  void _processIdentityAnnouncement(BitchatPacket packet, String peerID) {
    try {
      if (packet.payload == null) {
        return;
      }

      final announce = IdentityAnnouncement.decode(packet.payload!);
      if (announce != null) {
        // Update peer with nickname and public keys
        peerManager.updatePeer(
          peerID,
          name: announce.nickname,
          noisePublicKey: announce.noisePublicKey,
          signingPublicKey: announce.signingPublicKey,
        );

        // Notify delegate of peer list update
        final peerIds = peerManager.getAllPeers().map((p) => p.id).toList();
        delegate?.didUpdatePeerList(peerIds);

        debugPrint(
            '$_tag Identity announcement from $peerID: ${announce.nickname}');
      }
    } catch (e) {
      debugPrint('$_tag Error processing identity: $e');
    }
  }

  /// Processes a chat message packet.
  /// @param packet - The packet containing the message
  /// @param peerID - The peer ID that sent the message
  void _processChatMessage(BitchatPacket packet, String peerID) {
    debugPrint('$_tag ========================================');
    debugPrint('$_tag _processChatMessage CALLED');
    debugPrint('$_tag From peer: $peerID');
    debugPrint('$_tag ========================================');

    try {
      if (packet.payload == null) {
        debugPrint('$_tag *** ERROR: payload is NULL ***');
        return;
      }

      debugPrint('$_tag Payload size: ${packet.payload!.length} bytes');
      debugPrint(
          '$_tag Payload hex (first 60): ${packet.payload!.take(60).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

      debugPrint('$_tag Calling BitchatMessage.fromBinaryPayload...');
      final msg = BitchatMessage.fromBinaryPayload(packet.payload!);

      if (msg != null) {
        debugPrint('$_tag *** MESSAGE DECODE SUCCESS ***');
        debugPrint('$_tag Message ID: ${msg.id}');
        debugPrint('$_tag Message sender: ${msg.sender}');
        debugPrint('$_tag Message content: "${msg.content}"');
        debugPrint('$_tag Message channel: ${msg.channel}');
        debugPrint('$_tag Message timestamp: ${msg.timestamp}');

        // Look up nickname from PeerManager
        final peer = peerManager.getPeer(peerID);
        final senderName = peer?.name ?? peerID;
        debugPrint('$_tag Resolved sender name: $senderName');

        final messageWithPeerID = msg.copyWith(
          senderPeerID: msg.senderPeerID ?? peerID,
          sender: msg.sender.isEmpty ? senderName : msg.sender,
        );

        debugPrint(
            '$_tag Final message content: "${messageWithPeerID.content}"');
        debugPrint('$_tag Delegate is ${delegate == null ? "NULL" : "SET"}');

        // Notify delegate (UI layer) of the received message
        if (delegate != null) {
          debugPrint('$_tag Calling delegate.didReceiveMessage...');
          delegate!.didReceiveMessage(messageWithPeerID);
          debugPrint('$_tag delegate.didReceiveMessage completed');
        } else {
          debugPrint('$_tag *** ERROR: delegate is NULL, cannot notify UI ***');
        }
      } else {
        debugPrint('$_tag *** MESSAGE DECODE FAILED ***');
        debugPrint('$_tag Payload bytes: ${packet.payload!.toList()}');

        // Try to decode as plain UTF-8 string (Android might send simple format)
        try {
          final plainText = utf8.decode(packet.payload!, allowMalformed: true);
          debugPrint('$_tag Payload as UTF-8: "$plainText"');
        } catch (e) {
          debugPrint('$_tag Could not decode as UTF-8: $e');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('$_tag *** EXCEPTION in _processChatMessage ***');
      debugPrint('$_tag Error: $e');
      debugPrint('$_tag Stack: $stackTrace');
    }
  }

  /// Returns the current list of active (connected) peers.
  List<PeerInfo> getActivePeers() {
    return peerManager.getAllPeers().where((p) => p.isConnected).toList();
  }

  /// Returns the total number of peers (active and inactive).
  int getPeerCount() {
    return peerManager.getAllPeers().length;
  }

  /// Checks if the mesh service is currently active.
  bool get isActive => _isActive;

  // ---------------------------------------------------------------------------
  // Debug/Manual Connection Control
  // ---------------------------------------------------------------------------

  /// Disconnects a device by its address/UUID string.
  /// Used by debug UI to manually disconnect a connected device.
  Future<void> disconnectDevice(String deviceAddress) async {
    debugPrint('$_tag Disconnecting device: $deviceAddress');
    await _gattClientManager.disconnectByAddress(deviceAddress);
    // Also try to disconnect from server side if applicable
    _gattServerManager.disconnectCentral(deviceAddress);
  }

  /// Initiates a connection to a device by its address/UUID string.
  /// Used by debug UI to manually connect to a discovered device.
  Future<void> connectToDevice(String deviceAddress) async {
    debugPrint('$_tag Connecting to device: $deviceAddress');
    await _gattClientManager.connectByAddress(deviceAddress);
  }
}

/// Provider for the BluetoothMeshService.
/// Uses encryptionService as a dependency.
final meshServiceProvider = Provider<BluetoothMeshService>((ref) {
  return BluetoothMeshService(ref.watch(encryptionServiceProvider));
});

/// Provider for the EncryptionService.
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});
