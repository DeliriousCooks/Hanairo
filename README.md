# BooruWave UI and behavior update

This source overlay contains the updated Flutter `lib/` folder, BooruWave SVG mark, and `pubspec.yaml` asset registration.

## Apply it

1. Back up the current app folder.
2. Copy this `lib/` folder over the app's `lib/` folder.
3. Copy this `assets/` folder into the app folder.
4. Merge the asset entry from `pubspec.yaml` into your app's `pubspec.yaml`, keeping its current dependencies.
5. Run `flutter pub get`, then rebuild the iOS app.

## Changes in this update

- Fixed the nested keyboard resize and hide the bottom tab bar while the keyboard is open.
- Rebuilt post viewing around a swipeable, zoomable image viewer with per-image loading, fallback URLs, and clear unavailable-image states. Fixed overlay positioning that could trigger a blank/grey viewer.
- Restyled the viewer with an uploader/source header, post details, tags, and social-style save/share actions.
- Show loaded search result counts plus exact per-site counts for a single tag when the booru provides them.
- Show each selected site's translated search query. Added the `huge_penis` to `big_penis` e621 mapping alongside the existing aliases.

Tag aliases are maintained in `lib/core/tags/tag_translator.dart`; site vocabularies differ and the mapping table can be extended over time. The supplied archive lacked complete native build scaffolding, so keep the Android/iOS project files from your original app. This overlay contains no signing credentials or signing workflow files.
