import Testing
@testable import Demark

@MainActor
struct DemarkServiceOptionsTests {
    @Test("Custom bullet markers work with html-to-md engine")
    func customBulletMarkerHtmlToMd() async throws {
        let service = Demark()
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"

        let dash = try await service.convertToMarkdown(html, options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "-"))
        #expect(dash.contains("- Item 1"))
        #expect(dash.contains("- Item 2"))

        let plus = try await service.convertToMarkdown(html, options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "+"))
        #expect(plus.contains("+ Item 1"))
        #expect(plus.contains("+ Item 2"))

        let star = try await service.convertToMarkdown(html, options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "*"))
        #expect(star.contains("* Item 1"))
        #expect(star.contains("* Item 2"))
    }

    @Test("Bullet normalization does not touch fenced code blocks")
    func bulletNormalizationSkipsFencedCodeBlocks() async throws {
        let service = Demark()
        let html = "<pre><code>```\\n* not a list\\n```</code></pre>"

        let markdown = try await service.convertToMarkdown(
            html,
            options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "-")
        )

        #expect(markdown.contains("* not a list"))
    }

    @Test("Custom heading style is accepted")
    func customHeadingStyleAccepted() async throws {
        let service = Demark()
        let html = "<h1>Test Heading</h1>"
        let options = DemarkOptions(engine: .turndown, headingStyle: .setext)

        let markdown = try await service.convertToMarkdown(html, options: options)

        #expect(markdown.contains("Test Heading"))
    }
}

