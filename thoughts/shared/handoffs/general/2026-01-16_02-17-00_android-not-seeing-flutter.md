---
date: 2026-01-16T02:17:00-03:00
topic: "Android Not Seeing Flutter Messages"
status: in_progress
---

# Handoff: Android Not Seeing Flutter Messages

## Completed This Session
- ✅ Flutter recibe mensajes de Android
- ✅ Deduplicación funcionando (ID basado en hash de contenido)
- ✅ Nombre sender (parcial - aún muestra UID a veces)

## Issue Pendiente: Comunicación Unidireccional

**Síntoma:** Android NO recibe mensajes enviados desde Flutter

**Posibles causas:**
1. Flutter no está broadcasting correctamente via GATT notifications
2. Android no está suscrito a notifications del characteristic de Flutter
3. Formato de packet diferente (Flutter usa formato binario estructurado)

## Archivos Clave
- `lib/features/mesh/gatt_server_manager.dart` - `sendData()` para notifications
- `lib/features/mesh/bluetooth_mesh_service.dart:274-308` - `broadcastPacket()`

## Debug Steps
1. Verificar si `subscribedCentrals` tiene entries cuando Flutter envía
2. Verificar logs de `notifyCharacteristic`
3. Comparar formato de packet Flutter vs Android

## Cambios Hechos Esta Sesión
- `lib/data/models/bitchat_message.dart:165-174` - UTF-8 fallback + hash ID
- `lib/features/mesh/bluetooth_mesh_service.dart:559-561` - PeerManager lookup
- `lib/features/chat/chat_provider.dart:630-644` - Deduplication set

## Resume Command
```
/resume_handoff thoughts/shared/handoffs/general/2026-01-16_02-17-00_android-not-seeing-flutter.md
```
