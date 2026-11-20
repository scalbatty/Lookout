import Domain
import Foundation
import Testing
@testable import UnsplashAPI

struct UnsplashPhotoDomainTests {
    /// Builds a photo from a minimal JSON payload, overriding caption fields.
    private func photo(altDescription: String? = nil, description: String? = nil, user: [String: Any]? = nil) throws -> UnsplashPhoto {
        var json: [String: Any] = [
            "id": "abc",
            "width": 4000,
            "height": 3000,
            "alt_description": altDescription ?? NSNull(),
            "description": description ?? NSNull(),
            "urls": [
                "thumb": "https://images.unsplash.com/t?w=200",
                "small": "https://images.unsplash.com/s?w=400",
                "regular": "https://images.unsplash.com/r?w=1080",
                "full": "https://images.unsplash.com/f",
            ],
        ]
        json["user"] = user
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder.unsplash().decode(UnsplashPhoto.self, from: data)
    }

    @Test func captionPrefersAltDescription() throws {
        #expect(try photo(altDescription: "alt", description: "desc").caption == "alt")
    }

    @Test func captionFallsBackToDescription() throws {
        #expect(try photo(altDescription: nil, description: "desc").caption == "desc")
    }

    @Test func blankAltDescriptionCountsAsMissing() throws {
        #expect(try photo(altDescription: "  ", description: "desc").caption == "desc")
    }

    @Test func captionIsNilWhenBothMissing() throws {
        #expect(try photo().caption == nil)
    }

    @Test func creatorIsTheUsersName() throws {
        #expect(try photo(user: ["name": " Ana Lima "]).domainPhoto.creatorName == "Ana Lima")
    }

    @Test func creatorIsNilWhenUnnamedOrMissing() throws {
        #expect(try photo(user: ["name": "  "]).domainPhoto.creatorName == nil)
        #expect(try photo(user: ["username": "ana"]).domainPhoto.creatorName == nil)
        #expect(try photo().domainPhoto.creatorName == nil)
    }

    @Test func variantsUseFixedWidthsAndOriginalWidthForFull() throws {
        let variants = try photo().variants
        #expect(variants.map(\.pixelWidth) == [200, 400, 1080, 4000])
        #expect(variants.last?.url.absoluteString == "https://images.unsplash.com/f")
    }

    @Test func convertsRecordedFeedToDomain() throws {
        let photos = try JSONDecoder.unsplash()
            .decode([UnsplashPhoto].self, from: Fixture.data("photos-page"))
            .map(\.domainPhoto)

        #expect(photos.map(\.id) == ["WWyBQvJqvW8", "IIdlT7JMk9w", "B5RL__RyWio"])
        #expect(photos.map(\.isSponsored) == [true, false, false])
        #expect(photos.allSatisfy { $0.variants.count == 4 })
        #expect(photos[2].caption?.isEmpty == false) // description is null, alt_description is used
    }
}
