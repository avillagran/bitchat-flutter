# FASE 6: UI Principal - Chat (Semana 9-11)

## Tareas
- [x] 6.1 Implementar `ChatScreen` y componentes (message_bubble, chat_input, peer_list_sheet).
- [x] 6.2 Implementar `ChatProvider` (Riverpod) que expone `StateNotifier`/`AsyncValue` con la `ChatState`.
- [x] 6.3 Implementar procesamiento de comandos (`/join`, `/msg`, `/who`, `/block`).
- [x] 6.4 Implementar indicators (delivery, read, RSSI), favoritos y emergency wipe.

## Entregable
UI de chat funcional y conectada al mesh.

## Estado actual (2026-01-15)
**COMPLETADO:** UI básica funcional pero sin paridad visual con Android.

### Archivos implementados
```
lib/ui/
├── chat_screen.dart               # Main chat screen
├── widgets/
│   ├── message_bubble.dart        # Message display widget
│   ├── chat_input.dart            # Text input with mentions/channels
│   ├── peer_list_sheet.dart       # Bottom sheet with peers
│   ├── message_indicators.dart    # Delivery, read, RSSI indicators
│   ├── favorites_list.dart        # Favorites management
│   └── emergency_wipe_dialog.dart # Emergency data wipe

lib/features/chat/
├── chat_provider.dart             # Riverpod StateNotifier
├── command_processor.dart         # Command parsing and execution
```

### Tests implementados
```
test/features/chat/
├── chat_provider_test.dart
├── command_processor_test.dart    # 52 tests

test/ui/
├── chat_screen_test.dart
├── widgets/
│   ├── message_bubble_test.dart
│   ├── chat_input_test.dart
│   └── ...
```

### Comandos soportados
- `/join #channel` (`/j`) - Join a channel
- `/msg @user message` (`/m`) - Send private message
- `/who` - List connected peers
- `/block @user` - Block a user
- `/unblock @user` - Unblock a user
- `/help` (`/?`) - Show help

### Pendiente (FASE 7)
- **Paridad visual con Android** - Diferencias significativas detectadas

- [in_progress] Add Flutter color system tests (2026-01-16, AV)
  - Added `test/ui/utils/chat_ui_utils_test.dart` to replicate Android ColorTest and verify djb2 hashing, seed handling, and color visibility.
