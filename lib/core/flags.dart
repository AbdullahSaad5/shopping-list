/// Compile-time feature flags.
library;

/// Voice add (PLAN §3, locked decision on ticket #2): OFF by default and in
/// every v1 build. Flip with `--dart-define=VOICE_ADD=true`, which also
/// requires adding RECORD_AUDIO to AndroidManifest.xml and wiring a real
/// speech service into QuickAddBar's mic button — the manifest stays
/// permission-free until then so v1 ships with zero sensitive permissions.
/// When the flag is off the mic button is not built at all; the app degrades
/// to keyboard silently (engineering rule #8).
const bool kVoiceAddEnabled = bool.fromEnvironment('VOICE_ADD');
