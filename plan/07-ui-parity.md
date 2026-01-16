# FASE 7: Paridad Visual con Android (IN PROGRESS)

## Contexto
El análisis de paridad visual reveló diferencias significativas entre la UI de Flutter y la de Android. La UI de Android usa un estilo **terminal/IRC** muy distintivo que debe replicarse.

## Estado: EN PROGRESO (~90% complete)

---

## Diferencias detectadas

### 1. Esquema de colores
| Elemento | Android | Flutter actual |
|----------|---------|----------------|
| Fondo (dark) | `#000000` (negro puro) | ✅ Implementado |
| Main text | `#39FF14` (neon green) | ✅ Implemented |
| Mensajes propios | `#FF9500` (naranja) | ✅ Implementado |
| Fondo (light) | `#FFFFFF` | ✅ Implementado |
| Texto (light) | `#008000` (verde oscuro) | ✅ Implementado |

### 2. Tipografía
| Aspecto | Android | Flutter actual |
|---------|---------|----------------|
| Fuente | RobotoMono (monospace) | ✅ Implementado |
| Tamaño base | 15sp | ✅ Implementado |

### 3. Formato de mensajes
| Aspecto | Android | Flutter actual |
|---------|---------|----------------|
| Estilo | Texto inline IRC | ✅ Implementado |
| Formato | `<@nick#hash> msg [HH:mm:ss] ⛨Xb` | ✅ Implementado |
| Color por peer | djb2 hash → color | ✅ Implementado |

### 4. Input de texto
| Aspecto | Android | Flutter actual |
|---------|---------|----------------|
| Botón enviar | 30dp, `Icons.arrow_upward` | ✅ Implementado |
| Estilo | Minimalista, sin bordes | ✅ Implementado |

### 5. Header/AppBar
| Aspecto | Android | Flutter actual |
|---------|---------|----------------|
| Nickname | Editable inline | ✅ Implementado |
| Badges | Ubicación, Tor, PoW | ⏳ Pending |

---

## Tareas para implementar

### 7.1 Crear sistema de temas
- [x] `lib/ui/theme/bitchat_colors.dart` - Colores específicos UI
- [x] `lib/ui/theme/bitchat_typography.dart` - TextTheme monospace (RobotoMono, 15sp)
- [x] `lib/ui/theme/bitchat_theme.dart` - ColorScheme dark/light completo

### 7.2 Utilidades de UI
- [x] `lib/ui/utils/chat_ui_utils.dart` - djb2 hash para colores de peer, formateo IRC

### 7.3 Refactorizar MessageBubble
- [x] Eliminar burbujas, usar estilo IRC inline
- [x] Formato: `<@nickname#hash> mensaje [HH:mm:ss]`
- [x] Colores por peer usando djb2 hash
- [x] Indicadores como texto (⛨ para RSSI, ✓ para entrega)

### 7.4 Refactorizar ChatInput
- [x] Botón 30dp con `Icons.arrow_upward`
- [x] Sin bordes redondeados
- [x] Estilo minimalista

### 7.5 Actualizar ChatScreen
- [x] Aplicar tema nuevo
- [x] Header con nickname editable
- [ ] Badges de estado (ubicación, conexión) - partial, connection status done

### 7.6 Actualizar App
- [x] Aplicar tema en `lib/app.dart`

---

## Archivos creados/modificados

### Nuevos archivos:
- `lib/ui/theme/bitchat_colors.dart` - Sistema de colores terminal
- `lib/ui/theme/bitchat_typography.dart` - Tipografía RobotoMono
- `lib/ui/theme/bitchat_theme.dart` - ThemeData completo dark/light
- `lib/ui/utils/chat_ui_utils.dart` - Utilidades djb2, formateo IRC

### Archivos refactorizados:
- `lib/ui/widgets/message_bubble.dart` - Estilo IRC inline
- `lib/ui/widgets/chat_input.dart` - Botón 30dp minimalista
- `lib/ui/chat_screen.dart` - Header con nickname editable
- `lib/app.dart` - Aplicación de tema

---

## Historial de progreso
- [completed] 7.1-7.2 Theme system and utilities created — 2026-01-15 (OpenCode)
- [completed] 7.3-7.4 MessageBubble and ChatInput refactored — 2026-01-15 (OpenCode)
- [completed] 7.5 ChatScreen updated with editable nickname — 2026-01-15 (OpenCode)
- [completed] 7.6 App updated with BitchatTheme — 2026-01-15 (OpenCode)
- [verified] Build succeeded: `flutter build apk --debug` ✓ — 2026-01-15 (OpenCode)

---

## Tareas pendientes
- [x] LocationChannelsSheet - Geohash-based location channels (COMPLETED 2026-01-16)
- [ ] Add location/Tor/PoW badges to header (iOS parity)
- [ ] Test visual appearance on device
- [ ] Run `flutter test` to verify widget tests

---

### 2026-01-16 - Session 5: LocationChannelsSheet Implementation
**Agent: Claude**

#### Completed:
1. **GeohashUtils** (`lib/features/geohash/geohash_utils.dart`) - NEW FILE
   - Full geohash encode/decode implementation
   - Neighbor calculation (N, S, E, W, NE, NW, SE, SW)
   - Bounding box calculation
   - Adjacent geohash lookup

2. **LocationChannelManager** (`lib/features/geohash/location_channel_manager.dart`) - NEW FILE
   - Riverpod provider for location channel state
   - Join/leave channel logic
   - Current location geohash tracking
   - Neighboring channel discovery (precision 5-6)

3. **LocationChannelsSheet** (`lib/ui/widgets/location_channels_sheet.dart`) - NEW FILE
   - Bottom sheet UI matching Android design
   - Current location display with lat/lon
   - Geohash chips for current + 8 neighbors
   - Tap to join/leave channels
   - Visual feedback for joined channels
   - Terminal/monospace styling matching app theme

#### Files Created:
- `lib/features/geohash/geohash_utils.dart` - Geohash utilities
- `lib/features/geohash/location_channel_manager.dart` - Location channel state management
- `lib/ui/widgets/location_channels_sheet.dart` - Location channels UI sheet

#### Integration Points:
- Can be triggered from ChatScreen via action button
- Uses existing location service for coordinates
- Integrates with mesh service for geohash-based routing

#### Next Steps:
- Wire up location badge in ChatScreen header to open sheet
- Add geohash filtering to message broadcast logic
- Implement Nostr geohash event publishing (NIP-52 style)

---

## Prompt para continuar en nueva sesión

```
Continuamos desarrollando bitchat-flutter, un port de bitchat-android.

REGLAS:
- Yo hablo español, pero código/comentarios/docs en INGLÉS
- Referencia Android: /Users/avillagran/Desarrollo/bitchat-android
- Seguir AGENTS.md para convenciones

ESTADO ACTUAL:
- FASES 1-6 y 8 COMPLETADAS
- FASE 7 AL 90%: Paridad visual casi completa

ARCHIVOS YA CREADOS EN FASE 7:
- lib/ui/theme/bitchat_colors.dart ✓
- lib/ui/theme/bitchat_typography.dart ✓
- lib/ui/theme/bitchat_theme.dart ✓
- lib/ui/utils/chat_ui_utils.dart ✓
- lib/ui/widgets/message_bubble.dart (estilo IRC) ✓
- lib/ui/widgets/chat_input.dart (botón 30dp) ✓
- lib/ui/chat_screen.dart (nickname editable) ✓
- lib/app.dart (tema aplicado) ✓

TAREAS PENDIENTES:
1. Agregar badges de estado al header (ubicación, Tor, PoW)
2. Probar apariencia visual en dispositivo
3. Ejecutar flutter test para verificar tests

La app compila exitosamente. El build de Android funciona.
```
