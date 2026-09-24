# BooruWave UI update v5

This is a source overlay for the Flutter app you provided. It contains the updated `lib/` folder, BooruWave SVG asset, and `pubspec.yaml` registration.

## Apply it

1. Back up the current app folder.
2. Copy this `lib/` folder over your app's `lib/` folder.
3. Copy this `assets/` folder into the app folder.
4. Merge the asset entry from `pubspec.yaml` into your existing `pubspec.yaml`; keep your current dependencies.
5. Run `flutter pub get`, then rebuild your iOS app.

## Included changes

- Favorite saves update immediately in the viewer, search/feed cards, and Favorites tab.
- Video posts retain the app's post controls. Play/pause and scrubbing are compact controls within the video area.
- The viewer gives media its own space between the top bar and the action card, so the post no longer sits under the app controls.
- Added brighter violet/blue/cyan gradients, animated favorite feedback, and a more colorful Feed header.

The supplied archive did not include complete native build scaffolding. Keep the Android/iOS project files from your original app. No signing credentials or signing workflow files are included.
