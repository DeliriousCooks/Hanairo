# BooruWave UI update v13

This is a source overlay for the existing Flutter app. Copy the `lib` folder and the included logo asset over the matching paths in your project. No dependency changes are required.

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
