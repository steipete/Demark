import Testing
@testable import Demark

@MainActor
struct DemarkServiceBasicsTests {
    @Test("Basic conversion (Turndown)")
    func basicConversionTurndown() async throws {
        let service = Demark()
        let html = "<h1>Heading</h1><p>This is <strong>bold</strong> text.</p>"

        let markdown = try await service.convertToMarkdown(html, options: DemarkOptions(engine: .turndown))

        #expect(markdown.contains("# Heading"))
        #expect(markdown.contains("**bold**"))
    }

    @Test("List conversion uses default '-' bullets")
    func listConversionDefaultBullets() async throws {
        let service = Demark()
        let html = "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>"

        let markdown = try await service.convertToMarkdown(html)

        #expect(markdown.contains("- Item 1"))
        #expect(markdown.contains("- Item 2"))
        #expect(markdown.contains("- Item 3"))
    }

    @Test("Code block conversion preserves content")
    func codeBlockConversion() async throws {
        let service = Demark()
        let html = "<pre><code>console.log('hello');</code></pre>"

        let markdown = try await service.convertToMarkdown(html)

        #expect(markdown.contains("console.log('hello');"))
        #expect(markdown.contains("```") || markdown.contains("    console.log('hello');"))
    }

    @Test("Link conversion preserves href and label")
    func linkConversion() async throws {
        let service = Demark()
        let html = "<p>Visit <a href=\"https://example.com\">our website</a> for more info.</p>"

        let markdown = try await service.convertToMarkdown(html)

        #expect(markdown.contains("[our website](https://example.com)"))
        #expect(markdown.contains("Visit"))
    }
}
