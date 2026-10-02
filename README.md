# BooruWave UI update v18

This is the v18 source overlay, based on v17. Copy the `lib` folder and the included logo asset over the matching paths in your project. No dependency changes are required.

## v18 finishing fixes

- Vertically moved the search field itself down 12 logical pixels inside its unchanged-height dock so its hint and typed text line up with the search and filter buttons.
- Added horizontal swipes between the main tabs. A right swipe from Search returns to Feed; a left swipe moves to Favorites. The keyboard is dismissed during tab changes.
- Added a Recent Searches list to the empty Search screen. Tap a previous query to run it again, or Clear to erase local search history.
- Reset stale results on a fresh blank Search visit so the empty/recent state appears consistently.
# BooruWave UI update v17

This is the v17 source overlay, based on v16. Copy the `lib` folder and the included logo asset over the matching paths in your project. No dependency changes are required.

## v17 search-field alignment fix

- Vertically adjusted the search hint and entered text so they appear optically centered in the glass search dock.
# BooruWave UI update v16

This is the v16 source overlay, based on v15. Copy the `lib` folder and the included logo asset over the matching paths in your project. No dependency changes are required.

## v16 search-field finishing fix

- Removed the inherited filled-card background from the inline “Search tags…” field. The placeholder and entered text now sit directly on the main glass search dock, matching the supplied edited reference; the search dock, search button, filter button, and tag chips retain their own surfaces.
# BooruWave UI update v15

This is the v15 source overlay, based on v14. Copy the `lib` folder and the included logo asset over the matching paths in your project. No dependency changes are required.

## v15 finishing fixes

- Put selected search tags on their own horizontally scrollable row, auto-scroll to the newest tag, and keep the plain text entry borderless so its hint can never cover the chips.
- Added a clear-search control that removes all chips and text and returns Search to its empty state while preserving source and filter choices; in-flight results can no longer repopulate a cleared search.
- Kept autocomplete text separate from the submitted search query so pending suggestions can't corrupt result counts or interrupt a search after Enter.
- Fixed favorite-tag persistence when the list is empty (the previous empty-list value was immutable, so the first favorite could not be inserted). Added compatibility for older list-shaped stored values and made tag tap/hold use a Material ink gesture.
- Painted the glass edge above the clipped blur so rounded borders stay continuous, strengthened the compact search source-chip outlines, and reduced the bottom dock and selected-tab footprint.
- Updated Search when a tag link changes the route while Search is already open.

The original v14 notes follow.

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




## iOS Bundle ID

BooruBot uses `app.starfruit8199.boorubot` as its iOS Bundle ID. The provisioning profile used for signing must authorize this exact App ID; the CI workflow validates this instead of silently adopting the profile's old identifier.
