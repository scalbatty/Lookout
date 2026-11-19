import Foundation
import Testing
@testable import UnsplashAPI

struct UnsplashPhotoDecodingTests {
    @Test func decodesPhotosPage() throws {
        let photos = try JSONDecoder.unsplash().decode([UnsplashPhoto].self, from: Fixture.data("photos-page"))

        #expect(photos.map(\.id) == ["WWyBQvJqvW8", "IIdlT7JMk9w", "B5RL__RyWio"])
        #expect(photos[0].width == 2912)
        #expect(photos[0].height == 3640)
        #expect(photos[0].sponsorship != nil)
        #expect(photos[1].sponsorship == nil)
        #expect(photos[2].description == nil)
    }

    @Test func decodesSearchPage() throws {
        let response = try JSONDecoder.unsplash().decode(UnsplashSearchResponse.self, from: Fixture.data("search-photos-page"))

        #expect(response.total == 3179)
        #expect(response.totalPages == 1060)
        #expect(response.results.count == 3)
    }

    /// Guards the fixed rendition widths: if Unsplash ever changes its sizes,
    /// re-recording a fixture makes this fail.
    @Test(arguments: ["photos-page", "search-photos-page"])
    func renditionWidthsMatchRecordedURLs(fixture: String) throws {
        let data = try Fixture.data(fixture)
        let decoder = JSONDecoder.unsplash()
        let photos = fixture == "photos-page"
            ? try decoder.decode([UnsplashPhoto].self, from: data)
            : try decoder.decode(UnsplashSearchResponse.self, from: data).results

        for photo in photos {
            #expect(widthParameter(photo.urls.thumb) == UnsplashPhoto.RenditionWidth.thumb)
            #expect(widthParameter(photo.urls.small) == UnsplashPhoto.RenditionWidth.small)
            #expect(widthParameter(photo.urls.regular) == UnsplashPhoto.RenditionWidth.regular)
        }
    }

    private func widthParameter(_ url: URL?) -> Int? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first { $0.name == "w" }?.value.flatMap(Int.init)
    }
}
