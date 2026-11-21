# Lookout, an Unsplash photo explorer

## Features

- List the editorial content of Unsplash as an endless masonry grid (2 or 3 columns, depending on what fits)
- Search photos in the Unsplash library, in the same grid
- Tap a photo to see it full screen: zoom transition from the grid, pinch and double-tap to zoom, swipe up or down (or the arrows) for the next photo, photographer credit
- Loading states: breathing placeholders, columns evened out while the next page loads, retry on errors
- Added iPhone duo support because it felt like a good candidate for this

## Setup

Requires Xcode 27 (the project uses the new `project.xcproj` format) and iOS 17+.

1. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (gitignored).
2. Set `UNSPLASH_ACCESS_KEY` to your Unsplash **Access Key** (not the Secret Key), and `DEVELOPMENT_TEAM` to your team ID to run on a device.
3. Open `Lookout.xcodeproj` and run the `Lookout` scheme.

Tests (all logic lives in the `LookoutKit` package): open `Packages/LookoutKit` in Xcode and press ⌘U on an iOS Simulator, or from the command line:

```bash
cd Packages/LookoutKit
xcodebuild test -scheme LookoutKit-Package -destination 'platform=iOS Simulator,name=iPhone 17'
```

Debug launch arguments (in the scheme, off by default):

- `-ReplayRecordedFeed YES` replays 10 recorded feed pages, without using the API quota
- `-ReplayLatency <seconds>` delays each response, to see the loading states

Image downloads are logged in Debug builds:

```bash
xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "app.lookout" AND category == "ImagePipeline"'
```

## Technical choices

- **Modules.** One local Swift package, `LookoutKit`, with a module per responsibility (see the decision log). `Package.swift` sets what each module can see, so the compiler enforces the boundaries. The app target is the composition root: it builds the concrete repository and image loader once and injects them through initialisers, as protocols (`PhotoRepository`, `ImageLoading`). No singletons or service locator, so previews and tests swap in fakes the same way.
- **SwiftUI.** The grid held up in SwiftUI, so no `UICollectionView` was needed. UIKit is used in two places: a `UIScrollView` for zooming (SwiftUI has no zoomable scroll view), and dropping search focus on iOS 17.
- **Masonry.** A pure calculation places each photo in the shortest column; each column is a `LazyVStack`. A SwiftUI `Layout` would have been simpler, but it builds every cell at once.
- **Image pipeline.**
  - ImageIO decodes images at the size they're shown, never at full size.
  - Decoded images stay in a 100 MB memory cache; grid images are capped at 2× scale.
  - Downloads stay in a 300 MB disk cache.
  - Requests for the same image share one download.
  - Each new page's images are preloaded as it arrives.
  - A download nobody waits for any more is cancelled, after a 300 ms grace period so paging doesn't restart it.
  - Unsplash's fixed image widths are used instead of custom sizes, so requests hit its CDN cache.
  - Cancel what nobody needs, finish what was preloaded on purpose

## Performance

Measured in the simulator, Release build, replaying the recorded feed while scrolling:

| Step | Peak memory | Steady state |
|---|---|---|
| Naive loader | 380 MB | 186 MB |
| + Downsampling | 236 MB | 161 MB |
| + Cache, 2× cap, preloading | 244 MB | 217 MB, flat |

CPU while scrolling dropped from 52% to 29% busy. On a simulated slow network, 6 of 9 abandoned full-size downloads were cancelled while paging; with the grace period, none had to restart.

Not measured yet: on a real device, and hitches in Instruments.

## Trade-offs and improvements

- **API key.** It's in the app binary and can be extracted. A small backend proxy would keep it server-side.
- **Replay mode** ships in Release builds; it should be Debug only.
- **Offline.** Images are cached on disk but the feed isn't, and every network error is shown as "offline".
- **Placeholders.** The API's `blur_hash` is unused; it would make placeholders that look like the photo.
- **Tests.** Logic is unit tested; there are no UI or snapshot tests.
- **Known issue:** on an iPhone Duo, scrolling the grid on the outer screen then opening the device breaks the layout when scrolling back up.

## Note about AI Usage

I've used Claude Code as a pair-programming tool creating this project. Used Opus 5.5 on Low effort so it bounces back very frequently.

I've reviewed and endorse all the code that lies in the project and the commit history: every diff was reviewed before being committed.

- Independent features (header, zoom, photo paging, placeholders) were built in parallel Claude Code sessions.
- Review agents audited the code; I checked their findings before acting on them.
- Design and architecture decisions are mine, including where I pushed back on its suggestions.

## Log of decisions

Here are the decisions made for the project as I went, some might go back on previous ones.

- Architecture: one local Swift package (`LookoutKit`) with a module per responsibility. 
	- `Domain` holds Lookout's own model and knows nothing about Unsplash
	- `UnsplashAPI` is an adapter behind it
	- `ImageLoading` (interface) is separate from `ImagePipeline` (implementation) 
	- `GalleryFeature` only sees `Domain` and `ImageLoading`. 
	- The app target wires the concrete pieces together as a composition root. Dependency rules live in `Package.swift`, so the compiler enforces them.
- Build in Swift 6 mode from the get go, let's also ensure the app is easy to localize if needed
- I'm unsure about how SwiftUI will do with scrolling smoothness and performance but the brief insists on using SwiftUI as a default so I'll focus on writing a strong foundation with a SwiftUI view hierarchy first, then measure and see if I need to move to UICollectionView + custom UINavigationController transition for better results.
	- Update: measurements were good enough, SwiftUI stayed.
- Decided to hardcode the image variant widths in the Unsplash API code instead of checking the get parameters every time. Could be done later though.
- Decided to use stock iOS controls and behavior wherever possible: they come with accessibility built-in, feel familiar to users and are less code to maintain (the iPhone Duo compatibility comes easier that way too)
- Sponsored content is displayed and clearly labeled as such. Later we can add the sponsor's name and a link to their campaign URL if needed.
- Using page number instead of opaque cursor for pagination, as the brief indicates the page number in the API call example
- Using a RawRepresentable for the Photo ID to avoid String mixups.
- Using a seam for HTTP Calls so the unsplash repository code can be tested
- UnsplashPhotoRepository can be a structure as it has no mutable state
- Duplicate photo IDs across pages are skipped
- Added a debug replay build flag to keep the API calls-per-hour low while developing, testing and inspecting the app
- I wanted every view to be previewable in its multiple states (using Xcode previews)
- iOS 17 is supported but some behaviors or features aren't available on it (i.e. zoom animation)
- PhotoGridModel holds the logic so the view can be simpler, handling a defined set of states
- Same grid component for editorial and search
- Moved from a cropped square grid to a masonry layout, closer to Unsplash, with photos at their own shape, this shows better how the photos actually look and ensures we're not cropping out valuable details
- Replaced the system navigation bar with a custom header that scrolls away
- Dark only: photos read best on a dark page, and the zoom into the black full-screen view doesn't flash
- I decided to add buttons and gestures for previous/next photos, this wasn't in the requirements but felt very necessary when testing the app

