import Foundation

/// A string from GalleryFeature's own String Catalog. Views in a package
/// must look up their module's bundle, not the app's.
func localized(_ key: String.LocalizationValue) -> LocalizedStringResource {
    LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
}
