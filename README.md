# Bitchat (Flutter)

This repository contains the Flutter implementation of Bitchat — a cross-platform mesh/peer-to-peer chat application.

Summary
- This Flutter project is maintained in parity with the native implementations:
  - Android reference: https://github.com/permissionlesstech/bitchat-android
  - iOS reference: https://github.com/permissionlesstech/bitchat

## Executive Summary

Purpose: Port and maintain feature parity between the native Android implementation and a single Flutter codebase.
Target platforms: Android and iOS (primary), with macOS, Linux, and Windows supported as secondary targets.
Complexity: High — includes BLE mesh networking, Noise-based cryptography, Nostr integration, and optional Tor/Arti routing.

## Key Technical Decisions

- State management: Riverpod
- BLE: `flutter_blue_plus`
- Cryptography: Pure Dart (`pointycastle` / `cryptography`)
- Flutter version: 3.27.4 (FVM)
- Storage: Hive

## Project Plan (Phases)
1. [Setup and Infrastructure](plan/01-setup.md)
2. [Data Models & Protocol](plan/02-protocol.md)
3. [Cryptography & Noise](plan/03-crypto.md)
... (see `plan/` folder for full plan)

## Getting Started
1. Install [FVM](https://fvm.app/)
2. `fvm install`
3. `fvm flutter pub get`
4. `fvm flutter pub run build_runner build`

## Recent Changes (2026-01-16)
- `.gitignore` files updated to exclude build artifacts, binaries, generated files, and local LLM/agent files (examples: `.claude/`, `.opencode/`, `*.model`, `agent_logs/`).
- Documentation updated to reference official native repositories.

Security note
- Do not commit secrets, keystores, or model files. Use secure storage and environment management for credentials.
