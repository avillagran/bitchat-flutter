# FASE 5: Servicios Core y Background (Semana 8-9)

## Tareas
- [x] 5.1 Implementar `BackgroundService` (foreground service para Android).
- [x] 5.2 Implementar `NotificationService` con canales y notificaciones persistentes.
- [x] 5.3 Implementar `PermissionService`, `LocationService` y manejo de battery-optimization.
- [x] 5.4 Implementar almacenamiento seguro de claves/identidad.

## Estado actual (2026-01-15)
**COMPLETADO:** Todos los servicios core implementados.

### Archivos implementados
```
lib/features/mesh/
├── background_service.dart        # Foreground service with flutter_background_service

lib/features/notifications/
├── notification_service.dart      # Local notifications with persistence (Hive)

lib/features/permissions/
├── permission_service.dart        # BLE, location, notification permissions
├── location_service.dart          # Location updates with geolocator

lib/features/storage/
├── secure_storage_service.dart    # Secure key storage with flutter_secure_storage
```

### Tests implementados
```
test/features/mesh/
├── background_service_test.dart   # 17 tests

test/features/notifications/
├── notification_service_test.dart # 20+ tests

test/features/permissions/
├── permission_service_test.dart   # 15+ tests
├── location_service_test.dart     # 15+ tests

test/features/storage/
├── secure_storage_service_test.dart # 36 tests (13 passing, rest need native plugin)
```

### Funcionalidades
- **BackgroundService:**
  - Foreground service integration with flutter_background_service
  - Lifecycle hooks for app foreground/background transitions
  - Periodic mesh health checks
  - Automatic mesh restart on recovery

- **NotificationService:**
  - Local notifications with flutter_local_notifications
  - Notification channels (messages, system, emergency)
  - Persistence with Hive for unread messages
  - Android/iOS compatibility

- **PermissionService:**
  - BLE permissions (bluetoothScan, bluetoothConnect, bluetoothAdvertise)
  - Location permissions (locationWhenInUse, locationAlways)
  - Notification permissions
  - Battery optimization handling

- **LocationService:**
  - Location updates with geolocator
  - Background location tracking
  - Location accuracy settings

- **SecureStorageService:**
  - Identity key management (X25519, Ed25519)
  - Fingerprint generation and validation
  - Verified fingerprints storage
  - Peer data caching
  - Session metadata storage
  - General key-value storage
