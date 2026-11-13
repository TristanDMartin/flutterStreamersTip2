# Playback blockers

Neither item below is a passed device gate. Unit tests and CI do not
exercise MediaCodec or a physical iOS debug attach.

## Android MediaCodec BAD_INDEX

`CCodecConfig` / `setOutputSurface ... BAD_INDEX` is MediaCodec
rejecting a surface change while a decoder buffer is still queued.
The home player keeps routine widget keys stable and uses
`_surfaceRecoveryEpoch` in `lib/widgets/video_player_view_optimized.dart`
only when first-frame recovery explicitly recreates the texture.

The June 2026 scorecard still recorded this on Pixel 6. The texture
path logged fewer events than the Media3 home path
(`STREAMERSTIP_ANDROID_MEDIA3_HOME`). The matrix treats those counts
as informational unless `STRICT_CODEC_GATE=1`. The ship gate is
user-visible failure: first frame, video error, permission denied,
unrecovered surface recovery, or a failed test.

No player change is included here. A code change without a device
log would not show that BAD_INDEX stopped. Acceptance: a staging
device matrix on the shipping texture path reports
`first_frame_failures=0`, `video_errors=0`, and
`unrecovered_surface_playback_failures=0`, with `bad_index_count`
recorded. The gate stays open until that log exists.

## iOS Dart VM attach

Physical iOS `flutter test -d` was failing while discovering the Dart
VM service. The debug engine advertises that service over Bonjour.
`ios/Runner/Info.plist` had no `NSBonjourServices` or
`NSLocalNetworkUsageDescription`, which is a known reason iOS 14+
never discovers `_dartVmService._tcp`.

The plist now lists `_dartVmService._tcp` and `_dartobservatory._tcp`.
`scripts/classify_vm_service_attach.sh` marks a log `failed` when it
contains "Dart VM Service was not discovered" or "Error waiting for a
debug connection", and the matrix fails the gate on that result.

Acceptance: one physical iOS debug run completes `flutter test` attach
and the summary says `vm_service_attach=ok`. This VM cannot produce
that run.
