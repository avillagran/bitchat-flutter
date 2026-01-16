import 'package:flutter/foundation.dart';

/// Enum que representa el tipo de mensaje store-and-forward.
/// Puede extenderse para distinguir entre mensajes inbound, outbound, offline, etc.
enum StoreForwardMessageType {
  outbound,
  inbound,
  offline,
}

/// Modelo base para un mensaje store-and-forward para la malla.
/// (Puede expandirse con más campos según necesidades de protocolo.)
@immutable
class StoreForwardMessage {
  /// Identificador único del mensaje (por ejemplo, UUID).
  final String id;

  /// Carga útil principal (puede ser texto, bytes serializados, etc.).
  final Object payload;

  /// Identificador del destino (ej: peerId o dirección).
  final String destination;

  /// Marca de tiempo UTC de la inserción o creación (epoch millis).
  final int timestamp;

  /// Tipo de mensaje (outbound, inbound, offline, etc.).
  final StoreForwardMessageType type;

  const StoreForwardMessage({
    required this.id,
    required this.payload,
    required this.destination,
    required this.timestamp,
    required this.type,
  });
}

/// Gestor de cola store-and-forward para mensajes en la malla.
/// Soporta operaciones de encolado, extracción, consulta y limpieza.
/// Pensado para expandirse a persistencia o integración con peers.
/// Inspirado en patrones y estilo de PeerManager.
class StoreForwardManager extends ChangeNotifier {
  /// Cola interna en memoria para mensajes pendientes.
  final List<StoreForwardMessage> _pending = [];

  /// Encola un mensaje pendiente para ser enviado o procesado.
  /// Notifica listeners tras la operación.
  void enqueueMessage(StoreForwardMessage message) {
    _pending.add(message);
    // TODO: Hook para persistencia (almacenamiento local, BD, disco, etc.).
    notifyListeners();
  }

  /// Extrae y retorna el mensaje más antiguo de la cola.
  /// Retorna null si la cola está vacía.
  StoreForwardMessage? dequeueMessage() {
    if (_pending.isEmpty) return null;
    final msg = _pending.removeAt(0);
    // TODO: Hook para persistencia tras cambio en la cola.
    notifyListeners();
    return msg;
  }

  /// Elimina un mensaje por su id único.
  /// Retorna true si se eliminó algún mensaje.
  bool removeMessage(String id) {
    final before = _pending.length;
    _pending.removeWhere((m) => m.id == id);
    final removed = before != _pending.length;
    if (removed) {
      // TODO: Hook persistencia tras eliminación.
      notifyListeners();
    }
    return removed;
  }

  /// Devuelve snapshot actual de los mensajes pendientes (copia inmutable).
  List<StoreForwardMessage> getPendingMessages() => List.unmodifiable(_pending);

  /// Elimina los mensajes expirados según una función de expiración.
  /// Por defecto, expira mensajes con timestamp anterior a [expiryMillisAgo].
  int clearExpired({int expiryMillisAgo = 5 * 60 * 1000}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final initialLength = _pending.length;
    _pending.removeWhere((m) => (now - m.timestamp) > expiryMillisAgo);
    final removed = initialLength - _pending.length;
    if (removed > 0) {
      // TODO: Persistencia tras limpieza.
      notifyListeners();
    }
    return removed;
  }

  /// TODO: Implementar integración con almacenamiento persistente
  /// (ejemplo: Hive, SQLite, file, etc.) para durabilidad offline.
  /// TODO: Agregar hooks/eventos para sincronización en red o con peers al enviar/recibir.

  /// (Opcional) Borrar todos los mensajes (solo para pruebas o reinicio total).
  void clearAll() {
    _pending.clear();
    notifyListeners();
  }
}
