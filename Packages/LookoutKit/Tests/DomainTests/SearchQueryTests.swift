import Testing
import Domain

struct SearchQueryTests {
    @Test(arguments: ["", " ", "\n\t "])
    func rejectsBlankInput(raw: String) {
        #expect(SearchQuery(raw) == nil)
    }

    @Test func trimsSurroundingWhitespace() {
        #expect(SearchQuery("  tigers \n")?.text == "tigers")
    }

    @Test func queriesDifferingOnlyByWhitespaceAreEqual() {
        #expect(SearchQuery("tigers ") == SearchQuery("tigers"))
    }
}
