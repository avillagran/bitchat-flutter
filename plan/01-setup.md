# FASE 1: Setup e Infraestructura (Semana 1-2)

## Tareas
- [x] 1.1 Crear proyecto Flutter con FVM 3.27.x (`fvm install` + `fvm use`) y configurar `.fvmrc`.
- [x] 1.2 Añadir estructura de carpetas base y README de contribución.
- [x] 1.3 Configurar `pubspec.yaml` con dependencias iniciales.
- [x] 1.4 Configurar Riverpod y providers base (ejemplo de `ProviderScope`).
- [x] 1.5 Configurar Hive, adapters y `flutter_secure_storage` para claves.
- [x] 1.6 Migrar cadenas principales a `l10n` (crear `app_en.arb` y plantilla para otros idiomas).
- [ ] 1.7 Configurar temas (light/dark) y `go_router` básico. **[PENDING - NEXT TASK]**
- [x] 1.8 Configurar linting y CI básico (GitHub Actions) con `fvm` y `flutter format`.

## Entregable
Proyecto Flutter inicializable y compilable.

## Estado actual (2026-01-16)
- Proyecto compilable y ejecutable.
- Hive configurado en NotificationService y StoreForwardManager.
- SecureStorageService implementado con flutter_secure_storage.
- [completed] 2026-01-16 AV: Implemented native `MethodChannel` to handle battery-optimization checks and requests, and updated Flutter `PermissionService` to call it. Files touched: `android/app/src/main/kotlin/com/bitchat/bitchat/MainActivity.kt`, `lib/features/permissions/permission_service.dart`.
- Notes: Built and installed debug APK on device `J75T59BAZD45TG85`, granted runtime permissions via `adb` for testing, and collected focused logs; app still reports BLE "disconnected" — next step is targeted BLE logging and small debug prints in `lib/features/onboarding/onboarding_coordinator.dart` and `lib/features/mesh/ble_manager.dart`.
- **Pendiente:** Implementar tema visual con paridad Android (ver FASE 7).
