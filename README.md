# BooruWave UI update v8

This is a Flutter source overlay for the existing app. It contains updated `lib/`, the app asset folder, and a `pubspec.yaml` reference for dependencies/assets.

## Apply it

1. Back up your existing app folder.
2. Copy this package's `lib/` folder over your app's `lib/` folder.
3. Copy the included `assets/` folder into the app folder.
4. Merge the new `ffmpeg_kit_flutter_new_full` dependency and the asset entry from this `pubspec.yaml` into your existing `pubspec.yaml`; keep all your other dependencies.
5. Run `flutter pub get`, then rebuild.

The FFmpeg package used to convert WebM videos to MP4 requires iOS 14 or newer. The app's iOS `Info.plist` must include `NSPhotoLibraryAddUsageDescription` so the Photos save action can work. The supplied app source already includes that key in its Runner plist; retain it in your native project.

## Included changes

- Vertically centers the search text in the tag entry bar.
- Fixes Rule34.xxx/Gelbooru tag separators and handles their JSON or XML response shapes. Fixes Paheal parsing to read post elements.
- Raises each source's page size from 40 to 60. Pages load as you scroll; thumbnails decode at a capped width to limit memory use.
- Adds a mute/unmute button in the upper-right of the video frame; autoplay starts muted.
- Adds a Photos save action for images and videos. WebM videos are converted to MP4 before saving, with a fallback encoder if hardware encoding is unavailable.
- Makes tab selection capsules compact and separate so their accent colors no longer join into a single block.
- Uses OLED black with teal as the accent for the OLED preset.

This package is a source overlay and does not replace your app's native Android/iOS project files. Video conversion uses FFmpeg; the app bundle will be larger than before.
