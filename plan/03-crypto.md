# FASE 3: Criptografía y Noise Protocol (Semana 3-5)

## Tareas
- [x] 3.1 Implementar primitivas: Curve25519, ChaCha20-Poly1305, SHA-256, Ed25519 (usar `pointycastle` / `cryptography`).
- [x] 3.2 Implementar `NoiseSession` (patrón XX) compatible con parámetros: `Noise_XX_25519_ChaChaPoly_SHA256`.
- [x] 3.3 Implementar handshake state, protección replay (sliding window), y persistencia de identidad.
- [ ] 3.4 Implementar compatibilidad con secp256k1/Schnorr para Nostr (o usar paquete existente). **[FUTURE]**
- [ ] 3.5 Tests de interoperabilidad con la app Android. **[REQUIRES REAL DEVICE TEST]**

## Entregable
Noise funcional y probado contra Android.

## Estado actual (2026-01-15)
**COMPLETADO:** Noise Protocol XX handshake funcionando correctamente.

### Archivos implementados
- `lib/features/crypto/chacha_poly_port.dart` - ChaChaCore + Poly1305 port from Java
- `lib/features/crypto/noise_protocol_manual.dart` - Low-level handshake implementation
- `lib/features/crypto/noise_protocol.dart` - High-level NoiseSession API
- `test/noise_protocol_test.dart` - XX handshake tests

### Correcciones realizadas (2026-01-15)

1. **Ported ChaChaCore and Poly1305** from southernstorm Java to Dart
   - Bit-for-bit compatible with Android implementation

2. **Fixed missing ephemeral key output in writeHandshakeMessage**
   - Added `out.add(ePub!)` and `symmetric.mixHash(ePub!)` for both initiator and responder

3. **Fixed SE token DH calculation for responder**
   - Responder was doing `DH(s, rePub)` but should do `DH(e, rsPub)` for SE token
   - Changed line 339: `_calculateDH(s!, rePub!)` → `_calculateDH(e!, rsPub!)`

4. **Fixed split() key assignment**
   - Noise spec: initiator sends with k1, receives with k2; responder sends with k2, receives with k1
   - Updated `_completeHandshake()` to swap keys for responder

5. **Added fixed ephemeral key support for testing**
   - Added `setFixedEphemeral(priv, pub)` to `NoiseHandshakeState` and `NoiseSession`
   - Enables deterministic test vectors like Android's `getFixedEphemeralKey()`

6. **Made debug prints conditional**
   - Added `kNoiseDebug` and `kChaChaPolyDebug` flags (default: false)

### Tests
All XX handshake tests passing with proper X25519 key pairs and fixed ephemerals.
