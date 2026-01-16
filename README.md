# Bitchat (Flutter)

This repository contains the Flutter implementation of Bitchat — a cross-platform mesh/peer-to-peer chat application.

Summary
- This Flutter project is maintained to be in parity with native implementations:
  - Android reference: https://github.com/permissionlesstech/bitchat-android
  - iOS reference: https://github.com/permissionlesstech/bitchat

## Resumen Ejecutivo

Proyecto: Migrar `bitchat-android` (~60,000 LOC) a Flutter.
Plataformas objetivo: iOS y Android (prioridad), macOS, Linux, Windows (fase posterior).
Complejidad estimada: Alta — involucra BLE mesh networking, Noise Protocol, Nostr, Tor/Arti.

## Decisiones Técnicas Principales

- **State management**: Riverpod
- **BLE**: `flutter_blue_plus`
- **Criptografía**: Pure Dart (`pointycastle` / `cryptography`)
- **Flutter version**: 3.27.4 (FVM)
- **Almacenamiento**: Hive

## Plan de Proyecto (Fases)
1. [Setup e Infraestructura](plan/01-setup.md)
2. [Modelos y Protocolo](plan/02-protocol.md)
3. [Criptografía y Noise](plan/03-crypto.md)
... (ver carpeta `plan/`)

## Cómo Empezar
1. Instalar [FVM](https://fvm.app/)
2. `fvm install`
3. `fvm flutter pub get`
4. `fvm flutter pub run build_runner build`

## Recent Changes (2026-01-16)
- Updated `.gitignore` files to exclude binaries, build artifacts, generated files, and local LLM/agent files and caches (examples: `.claude/`, `.opencode/`, `*.model`, `agent_logs/`).
- Added documentation notes about keeping parity with native Android/iOS repos.

Note: Keep repository free of secrets, keystores, and model files.
