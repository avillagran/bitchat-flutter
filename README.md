# Bitchat (Flutter)

This repository contains the Flutter implementation of Bitchat — a cross-platform mesh/peer-to-peer chat application.

Summary
[![Install APK](https://img.shields.io/badge/Install-APK-green)](https://github.com/avillagran/bitchat-flutter/releases/download/v0.1/app-release.apk)
- This Flutter project is maintained in parity with the native implementations:
  - Android reference: https://github.com/permissionlesstech/bitchat-android
  - iOS reference: https://github.com/permissionlesstech/bitchat

## Executive Summary

Purpose: Port and maintain feature parity between the native Android implementation and a single Flutter codebase.
Target platforms: Android and iOS (primary), with macOS, Linux, and Windows supported as secondary targets.
Complexity: High — includes BLE mesh networking, Noise-based cryptography, Nostr integration, and optional Tor/Arti routing.

## Key Technical Decisions

- State management: Riverpod
- BLE: `bluetooth_low_energy`
- Cryptography: Pure Dart (`pointycastle` / `cryptography`)
- Flutter version: 3.27.4 (FVM)
- Storage: Hive


## Getting Started
1. Install [FVM](https://fvm.app/)
2. `fvm install`
3. `fvm flutter pub get`
4. `fvm flutter pub run build_runner build`

## Recent Changes (2026-01-16)

- BLE platform plugin integrated via `bluetooth_low_energy` (platform implementations present for Android, iOS/darwin, Windows and Linux).
- Pigeon-generated platform bindings restored (`packages/bluetooth_low_energy_bitchat/lib/src/my_api.g.dart`) to enable native <> Dart BLE APIs.
- Release APK generated at `build/app/outputs/flutter-apk/app-release.apk` (will be uploaded as release asset `v0.1`).
- Core libraries configured: Riverpod for state management, Hive for local storage, and `flutter_secure_storage` for credentials; cryptography libraries set up (`pointycastle`/`cryptography`).

Security note
- Do not commit secrets, keystores, or model files. Use secure storage and environment management for credentials.
