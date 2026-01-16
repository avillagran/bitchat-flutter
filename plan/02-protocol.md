# FASE 2: Modelos de Datos y Protocolo Binario (Semana 2-3)

## Tareas
- [x] 2.1 Modelos con `freezed` (BitchatMessage, Peer, Channel, Identity, RoutedPacket, NostrEvent).
    - [x] BitchatMessage
    - [x] RoutedPacket (placeholder)
    - [x] BitchatFilePacket
    - [x] FragmentPayload
    - [x] IdentityAnnouncement
    - [x] RequestSyncPacket
- [x] 2.2 Implementar `BinaryProtocol` y `PacketCodec` con compatibilidad del header de 13 bytes.
- [x] 2.3 Implementar tipos de mensaje (enum) y codificación/decodificación, fragmentación/ensamblado.
- [ ] 2.4 Añadir util de compresión (LZ4 o deflate según parity Android). **[LOW PRIORITY]**
- [x] 2.5 Tests unitarios de serialización/deserialización (compatibilidad con Android).

## Entregable
Modelos y codecs probados.

## Estado actual (2026-01-15)
- Modelos freezed completos y funcionales.
- PacketCodec con header de 13 bytes compatible con Android.
- FragmentManager implementado para fragmentación/reensamblado.
- Tests unitarios pasando.
