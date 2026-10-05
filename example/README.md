# file_launcher gallery

Run `flutter run` on an iOS or Android device. Browse Documents, Audio, Video, Images, Data and Other. Tap a sample, then close the native screen before opening another.

The gallery bundles 19 valid small fixtures. MP3, M4A/AAC, PCM WAV, FLAC, Vorbis Ogg, Opus Ogg and raw AAC audio contain a three-second soft 440 Hz test tone. These are generated test assets, not user documents or licensed music. The unknown-format fixture deliberately has no standard format. The extensionless fixture contains a valid PDF and sends an Android MIME override.

The status card shows the result and elapsed time. A successful launch does not establish correct rendering or playback: inspect the page/image or listen to the sample on the device. The missing-file action exercises a failure without presenting native UI.

Temporary samples remain in OS-managed storage so viewers can finish reading them. See [the device matrix](../TESTING.md).
