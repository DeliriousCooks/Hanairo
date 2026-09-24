# BooruWave UI update v14

This is a source overlay for the existing Flutter app. Copy the `lib` folder and the included logo asset over the matching paths in your project. No dependency changes are required.

## Changes in v14

- Reworked Search into a more substantial floating glass dock: separate search and filter controls, a plain inline query field, horizontally scrolling tag chips, and rounded suggestions.
- Increased tab dock contrast and label legibility so the icons and names stay clear against changing content behind the glass.
- Added Posts and Favorite Tags sections to Favorites. Tap a post tag to search it; press and hold briefly to save or remove it from Favorite Tags.
- Added a persistent 2 / 3 / 4 column control to Feed, sharing the saved Grid Columns preference with Settings and Favorites. The default remains the existing two-column feed.
- Added a single-post feed mode that loads the original image URL and fits the complete image inside the media area. Double-tap to favorite and press and hold to export an image or video to Photos.
- Reused the Photos export helper in both the single-post feed and full-screen viewer, including the existing WebM-to-MP4 conversion path.
- Fixed the missing closing parenthesis in the search input reported by the iOS release build.

## Finishing fixes

- Removed the extra inset search-field box so tags and query text sit in the main glass search dock. Tapping a suggestion adds it to the query and keeps Search open; search submission now happens on the keyboard's Search/Enter action.
- Made favorite-tag gestures work both in the post tag panel and on the visible tag chips. Tap to search; press and hold to save or remove the tag, with an immediate confirmation and saved-state indicator.
- Increased the glass dock's edge contrast and inset spacing around the tab highlight so the tab bar border stays visible.
- Tied video playback to the active viewer page and single-post feed visibility. Swiping pauses and mutes the old video; the feed resumes it only if that same post remains in view.

## Changes in v13

- Added a persistent grid / single-column feed switch.
- Replaced the feed's generic “Following” concept with a Saved Tag Mix that loads recent posts for saved searches. Save or remove a tag from the search results header; saved tags also appear as quick links on Feed.
- Kept stories out of the Feed.
- Enlarged the search input and constrained its width so the typed text has room beside chips.
- Dismissed the keyboard on search submission and before opening a post.
- Added exact tag counts to the first five autocomplete suggestions, summed across enabled sources. Search result headers show the combined tag count in bold with per-source counts below.
- Validated Rule34.xxx's numeric User ID and API key against its API before reporting an account connection as successful.
- Updated WebM-to-MP4 conversion success checks to use FFmpegKit's `ReturnCode.isValueSuccess()` API, avoiding the unresolved `ReturnCode` symbol from the previous iOS build log.

The Rule34 account form uses its API User ID and generated API key because the site's API requires credentials for API requests. See the [Rule34 API help](https://rule34.xxx/?page=help&topic=dapi) and [API key announcement](https://rule34.xxx/index.php?id=9793&page=forum&pid=45&s=view).

## Changes in v12

- Added an adaptive, clipped glass surface for the floating navigation dock, home quick-search control, and search header/input.
- Kept the selected tab highlight compact, with a softer tint in light mode and a contained accent in dark mode.
- Added the Petal theme preset to match the newer pastel direction; OLED Black remains available.
- Added light haptic feedback when changing destinations.

The glass surfaces use Flutter's `BackdropFilter` with translucent fills and edge highlights. They are a Liquid Glass-inspired cross-platform treatment, not Apple's native refractive `UIGlassEffect`. Flutter's current iOS compatibility page says iOS 26 is supported and tracks Liquid Glass as a feature not yet fully implemented in the framework. The same UI has a fallback on older iOS and Android. No iOS 27-specific API is assumed.

Glass is limited to navigation and search controls so the art and feed content remain visually clear.

## Changes

- Gave each tab a fixed, compact highlight capsule and made the dock surface opaque enough to keep the background colors from blending across the bar.
- Added a short fade and lift animation when changing tabs.
- Stopped empty Feed and Search screens from bouncing into a larger blank area.
- Made source chips refresh an active query immediately.
- Added adjacent-post preloading and clipped, non-bouncing paging in the full-screen viewer.
- Updated Paheal post and tag requests to Shimmie's current API routes.
- Kept API errors and authentication failures visible instead of showing them as zero results. Failed Rule34 and Gelbooru requests include a direct account connection action.
- Fixed Gelbooru credentials to use User ID and API Key fields, and passed saved Rule34/Gelbooru credentials to search, tag-count, and suggestion requests.

Rule34 currently requires API credentials for API search requests. Gelbooru may require them at times. The auth screens explain where to retrieve each site's credentials.
