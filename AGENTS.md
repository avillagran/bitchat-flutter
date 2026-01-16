# AGENTS.md

_Bitchat Flutter – Agentic Coding Guidelines_

## Overview
This document provides essential instructions for coding agents and developers working in this Flutter/Dart repository. Follow these rules and conventions for high code quality, consistency, and effective collaboration. These guidelines are authoritative; ask for clarification if ambiguous or conflicts arise.

---

## 1. Build, Lint, and Test Commands

### Build
- **Main build:**
  ```bash
  flutter build <platform>
  # e.g., flutter build apk, flutter build ios
  ```
- **Clean build artifacts:**
  ```bash
  flutter clean
  ```

### Linting & Static Analysis
- **Run Flutter analyzer (all files):**
  ```bash
  flutter analyze
  ```
- **Lint rules:**
  Project extends `flutter_lints`, see below for details.

### Test
- **Run all tests:**
  ```bash
  flutter test
  ```
- **Run a specific test file:**
  ```bash
  flutter test test/<test_file.dart>
  ```
- **Run test(s) matching description via regex:**
  ```bash
  flutter test --name "<Test name regex>"
  ```
- **Run test(s) matching plain name substring:**
  ```bash
  flutter test --plain-name "<part of test name>"
  ```
- **Recommended (single test as run by AGENTS):**
  ```bash
  flutter test --plain-name "test description name here"
  # e.g. flutter test --plain-name "Initiator and Responder can complete XX handshake"
  ```
- **Run tests in a specific directory:**
  ```bash
  flutter test test/<directory>
  ```

---

## 2. Code Style Guidelines

### Imports
- Use relative imports within `lib/`, absolute for package dependencies.
- Group dart imports: Dart SDK, external packages, then local files.
- Alphabetize imports in each group.
- Avoid unused/duplicate imports.
- For generated code, import via `part of` and annotate as auto-generated if modifying.

### Formatting
- **Follow `dartfmt`/Flutter defaults.**
  - Indent with 2 spaces; no tabs.
  - Limit lines to 80–100 chars.
  - Space after commas, no trailing whitespace.
  - Braces on same line as definition (Dart/Flutter default).
  - Use trailing commas in multi-line lists/maps/constructor args where possible.
- **Use `flutter format .` as-needed.**

### Variables, Types, Declarations
- **Always specify types explicitly** if not trivially inferable.
- Prefer `final`/`const` for variables where possible (`prefer_final_locals`).
- Use `late` only if necessary (e.g., uninitialized at declaration).
- Null safety: avoid `dynamic` and nullable fields unless truly needed; prefer non-nullable typing.

### Naming Conventions
- **Classes/Types:** PascalCase (e.g., `NoiseSession`, `BitchatMessage`)
- **Methods/Fields/Variables:** camelCase (e.g., `startHandshake`, `isRelay`)
- **Constants:** UPPER_SNAKE_CASE (e.g., `NOISE_PROTOCOL_NAME`)
- **Files:** snake_case (e.g., `encryption_service.dart`)
- **Avoid abbreviations unless industry-standard (e.g., `id`, `URL`).**
- Be descriptive but not verbose.

### Error Handling
- **Throw informative, custom exceptions** when you expect errors.
- Avoid catching blindly (`catch (e) {}`), always handle errors sensibly or rethrow.
- Use `try/catch` with precise exception types if available.
- Never print sensitive data (keys, payloads) in logs.
- In hot paths (e.g. mesh or crypto), fail early and log with context.

### Comments & Documentation
- Use `///` doc comments for public APIs, classes, and key methods.
- Inline comments (`// ...`) should explain non-obvious logic only.
- Do not overdocument; prefer clear code to verbose comments.
- Mark all `TODO:` and `FIXME:` for tracking with owner/issue if possible.
- **Language rule (enforced):** All code, documentation, and comments MUST be in English. The maintainers communicate with agents in Spanish, but the repository source code must always be in English for international consistency and reviewability.

### Flutter/Dart Specific Lints (via `flutter_lints`)
This project inherits all `flutter_lints`:
- Avoid `print`; use proper logging.
- Prefer `const` for constructors/values.
- Avoid unnecessary containers in widgets.
- Use set/get conventions for properties (no returns on setters).
- Use collection methods with `isEmpty`/`isNotEmpty`, not `length == 0`.
- Do not ignore returned futures unless appropriate.
- Prefer explicit typing even where Dart can infer.
- Avoid positional boolean parameters; use named when possible.
- Always include a `default` in switch over enums unless exhaustive.
- No unused/duplicate imports, dead code, or variables.

---

## 3. Dart & Agentic Coding Patterns

### Agentic Coordination
- **Coordinator role:** For this session, the primary agent acts as a coordinator and will delegate specialized tasks to GPT-5-mini subagents (similar to GitHub Copilot).
- **Delegation:** Each complex, multi-step, or platform-specific implementation block (e.g., PeerManager, StoreForwardManager, GattServerManager, PowerManager) should be delegated to a subagent.
- **Parallel execution:** When tasks are independent, delegate them to multiple subagents in parallel.
- **Subagent workflow:** Provide clear requirements, scope, and expected outputs; subagent returns implementation and unit tests; coordinator reviews and integrates.
- **Reporting:** Coordinator updates plan files and commits; subagents focus on clean, well-documented code and test coverage.
- **Consistency:** All subagent output must follow this AGENTS.md (English docs/comments, naming, error handling, no comments in user language).


### Packages in Use
Project depends (see pubspec.yaml) on: `flutter_riverpod`, `freezed`, `hive`, `json_serializable`, `flutter_blue_plus`, `pointycastle`, `cryptography`, `flutter_secure_storage`, `web_socket_channel`, `go_router`, and others for mesh, BLE, services, and notifications.
- When modifying code, ensure you read types, interfaces, and generated APIs for these.
- Use `freezed` for data models and unions; all models should be immutable-by-default.
- Use Riverpod for state management (providers, not singletons, unless legacy code).

### Tests
- Place all tests in `test/`, named with `_test.dart` suffix.
- Use `flutter_test`'s `test`, `group`, `testWidgets` appropriately.
- Use meaningful test descriptions; prefer "should do X when Y" style.
- Test both normal and failure cases.
- Ensure all test dependencies are included in `dev_dependencies` in pubspec.yaml.
- Prefer fast, deterministic unit tests; use widget/integration tests for UI flows.

---

## 4. Conventions in This Repo

### Android Parity and Permissions
- This project **must be maintained as an IDENTICAL COPY** of the reference Android project located at:
  `/Users/avillagran/Desarrollo/bitchat-android`
- Coding agents and developers **have standing, global permission to read and analyze any and all files within that Android project** for the purpose of comparison, replication, architecture migration, or functionality syncing.
- Do not request explicit user permission for each read or exploration of the Android codebase: the above serves as continuous, full authorization.
- If any ambiguity exists, prioritize keeping the Flutter codebase in strict parity with the Android version, except for platform differences.

### Development Plan Location & Update Rules
- The canonical development plan for cross-repo parity lives in the `plan/` folder at the repository root. Agents MUST update the plan files as work progresses.
- Current plan files (update this list if files are added or removed):
  - `plan/01-setup.md`
  - `plan/02-protocol.md`
  - `plan/03-crypto.md`
  - `plan/04-mesh.md`
  - `plan/05-core-services.md`
  - `plan/06-ui-chat.md`
- When you start or complete work on a task, update the corresponding `plan/*.md` file with:
  - A short status line (e.g., `- [in_progress] Implement Noise handshake`) with timestamp and agent initials.
  - A 1–2 sentence summary of changes made and files touched.
  - Any follow-up tasks or open questions.
- Agents should not make the plan out-of-sync: always update the `plan/` file immediately after making code changes or before opening a PR.

- Do not add external files (.dart, asset) except in approved locations.
- No secrets or credentials in code or .env files; use `flutter_secure_storage` instead.
- Generated files (`*.freezed.dart`, `*.g.dart`) should never be manually edited.
- If workflow/CI tools are used, adapt patterns here for automation.
- If agentic code writes migrations or refactors, always run tests and `flutter analyze` afterward.
- Document any newly-enforced conventions or custom rulesets here with clear rationale.

---

## 5. References

- [flutter_lints README](https://pub.dev/packages/flutter_lints)
- [Dart Effective Guide](https://dart.dev/guides/language/effective-dart)
- [Flutter Testing Docs](https://docs.flutter.dev/cookbook/testing/unit/introduction)

---

_Last updated automatically for agentic developer use. Please update with any new repo-wide convention changes._
