# Flutter SDK pin

Supported SDK: **3.50.0** (Dart 3.14).

Local development uses `.fvmrc`. GitHub Actions pins
`flutter-version: "3.50.0"` instead of floating `channel: stable`.
CI checks that `flutter --version` starts with `Flutter 3.50.0`.

## Why not 3.35.7

`.fvmrc` previously pinned 3.35.7 while CI installed current stable
(3.50.0). 3.35.7 does not compile this app:
`SemanticsService.sendAnnouncement` in
`lib/services/accessibility_service.dart` exists only after 3.35.

## Analyzer exception (temporary)

Flutter 3.50 marks the entire `package:flutter/material.dart` library
deprecated (`deprecated_member_use`) and `flutter analyze` treats infos
as fatal. `package:flutter/material_ui.dart` is not in the 3.50 SDK, so
the app cannot migrate those imports yet.

CI runs `flutter analyze --no-fatal-infos` for that reason only.
Errors and warnings still fail the build. Do not add a blanket
`deprecated_member_use` ignore. That would hide real deprecations,
including admin-allowlist and API removals.

Acceptance for removing `--no-fatal-infos`:

- The replacement Material library is in the pinned SDK.
- App imports are migrated.
- `flutter analyze` with fatal infos exits 0 on the pinned SDK.
