# BooruWave UI update v10

This source overlay fixes the bottom dock sizing regression. It contains updated `lib/`, the app assets, and a `pubspec.yaml` reference. Apply it over the version you already integrated, or merge its updated `lib/main.dart` into your current project.

## Dock fix

The floating tab dock now has a fixed 76-pixel height, stays aligned to the bottom safe area, and keeps each selected tab in its own compact capsule. Its glass blur is clipped to the dock instead of filling the screen.

This overlay also carries the latest prior fixes: search field alignment, source search parsing, 60-post pages, video mute and save/MP4 conversion, and the FFmpeg ReturnCode import.

If you only want the dock fix, replace `lib/main.dart` from this package in your project. No dependency changes are needed for this fix.
