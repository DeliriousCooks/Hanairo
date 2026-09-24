# BooruWave UI update v11

This is a source overlay for the existing Flutter app. Copy the `lib` folder and the included logo asset over the matching paths in your project. No dependency changes are required.

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
