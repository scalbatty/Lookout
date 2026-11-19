// swift-tools-version: 6.0
import PackageDescription

// Dependency rules (enforced by the targets below):
//
//   Domain          → nothing. Lookout's own model and interfaces.
//   ImageLoading    → nothing. Image loading interface only.
//   ImagePipeline   → ImageLoading. The concrete loader (cache, decode, cancel).
//   UnsplashAPI     → Domain. Unsplash is an adapter behind Domain's interfaces.
//   GalleryFeature  → Domain, ImageLoading. Never Unsplash, never the pipeline.
//
// Only the app target sees the concrete modules and wires them together.

let package = Package(
    name: "LookoutKit",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "ImageLoading", targets: ["ImageLoading"]),
        .library(name: "ImagePipeline", targets: ["ImagePipeline"]),
        .library(name: "UnsplashAPI", targets: ["UnsplashAPI"]),
        .library(name: "GalleryFeature", targets: ["GalleryFeature"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "ImageLoading"),
        .target(name: "ImagePipeline", dependencies: ["ImageLoading"]),
        .target(name: "UnsplashAPI", dependencies: ["Domain"]),
        .target(name: "GalleryFeature", dependencies: ["Domain", "ImageLoading"]),
    ]
)
