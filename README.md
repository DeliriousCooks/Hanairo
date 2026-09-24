# BooruWave UI update v6

This source overlay updates the Flutter app you supplied. It includes `lib/`, the BooruWave SVG asset, and `pubspec.yaml`.

## Apply it

1. Back up your existing app folder.
2. Copy this package's `lib/` folder over the app's `lib/` folder.
3. Copy the included `assets/` folder into the app folder.
4. Merge the asset entry in `pubspec.yaml` into your app's file, keeping the dependencies already present in your project.
5. Run `flutter pub get`, then rebuild the app.

## Included changes

- Cleans source and formatting markers from post descriptions.
- Displays the sum of tag counts across enabled booru sites, with each site's count beside it.
- Gives the bottom tab dock a larger, rounded shape and keeps all tab labels visible.
- Lets you swipe down to dismiss the viewer and the tag details panel.
- Opens each post's source page in the browser.
- Opens the platform share sheet with the source link and full-size image. iOS offers its available copy and save actions there.
- Prefers original media URLs in the viewer and keeps lower-resolution fallbacks if the original cannot load.
- Adds an OLED Black theme preset with black backgrounds and surfaces.

The combined tag total adds each site's count; booru sites may contain overlapping posts. This package is a source overlay and does not contain the original app's complete Android/iOS build scaffolding.
