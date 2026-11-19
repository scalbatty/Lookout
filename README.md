# Lookout, an Unsplash photo explorer

## Features

- List the editorial content of Unsplash as an endless grid of photos
- Search photos in the Unsplash library
- Each photo in a grid can be tapped to be displayed full screen

## Setup

Requires Xcode 27 (the project uses the new `project.xcproj` format) and iOS 17+.

1. Copy `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` (gitignored).
2. Set `UNSPLASH_ACCESS_KEY` to your Unsplash **Access Key** (not the Secret Key).
3. Open `Lookout.xcodeproj`, select your signing team, and run the `Lookout` scheme.

Tests: run the `LookoutKit-Package` scheme on an iOS Simulator (⌘U).

## Note about AI Usage

I've used Claude Code as a pair-programming tool creating this project. Used Opus 5.5 on Low effort so it bounces back very frequently.

I've reviewed and endorse all the code that lies in the project and the commit history.

## Log of decisions

Here are the decisions made for the project as I went, some might go back on previous ones.

- Architecture: one local Swift package (`LookoutKit`) with a module per responsibility. 
	- `Domain` holds Lookout's own model and knows nothing about Unsplash
	- `UnsplashAPI` is an adapter behind it
	- `ImageLoading` (interface) is separate from `ImagePipeline` (implementation) 
	- `GalleryFeature` only sees `Domain` and `ImageLoading`. 
	- The app target wires the concrete pieces together as a composition root. Dependency rules live in `Package.swift`, so the compiler enforces them.
- I'm unsure about how SwiftUI will do with scrolling smoothness and performance but the brief insists on using SwiftUI as a default so I'll focus on writing a strong foundation with a SwiftUI view hierarchy first, then measure and see if I need to move to UICollectionView + custom UINavigationController transition for better results.
- Decided to hardcode the image variant widths in the Unsplash API code instead of checking the get parameters every time. Could be done later though.
- Sponsored content is displayed and clearly labeled as such
- Using page number instead of opaque cursor for pagination, as the brief indicates the page number in the API call example

