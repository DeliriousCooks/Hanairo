# BooruWave UI update

This is a source overlay for the Flutter project you provided. It contains the updated `lib/` screens, the BooruWave SVG brand asset, and the matching `pubspec.yaml` asset registration.

## Apply it

1. Make a backup of your app folder.
2. Copy this `lib/` folder over your app's `lib/` folder.
3. Copy this `assets/` folder into your app folder.
4. Add the `assets/images/booruwave_mark.svg` entry under `flutter: assets:` in your existing `pubspec.yaml` (or merge the supplied pubspec changes; keep your existing dependencies).
5. From your app folder, run `flutter pub get`, then open the project in Claude Code.

## What changed

- Replaced the initial landing tab with a multi-source Feed, including Popular/Latest sorting, source filters, refresh, and two-column image cards.
- Added the five-tab Feed, Search, Favorites, Account, Settings navigation from the reference design.
- Added the Account screen with local favorites, search history, connected booru accounts, and shortcuts to existing settings/auth pages.
- Added favorite buttons to feed and search post cards, wired to the app's local favorites storage.
- Refined post cards with rounded corners, tag chips, source badges, and glassy favorite controls.
- Added a reusable BooruWave SVG mark.

The supplied archive did not contain complete Android/iOS build scaffolding, so this is deliberately a source overlay; retain the native project files from your original project. No signing credentials or signing workflow files are included.
