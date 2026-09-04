import Testing
@testable import Demark

@MainActor
struct DemarkServiceOptionsTests {
    @Test("Custom bullet markers work with html-to-md engine")
    func customBulletMarkerHtmlToMd() async throws {
        let service = Demark()
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"

        let dash = try await service.convertToMarkdown(
            html,
            options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "-")
        )
        #expect(dash.contains("- Item 1"))
        #expect(dash.contains("- Item 2"))

        let plus = try await service.convertToMarkdown(
            html,
            options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "+")
        )
        #expect(plus.contains("+ Item 1"))
        #expect(plus.contains("+ Item 2"))

        let star = try await service.convertToMarkdown(
            html,
            options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "*")
        )
        #expect(star.contains("* Item 1"))
        #expect(star.contains("* Item 2"))
    }

    @Test("Bullet normalization does not touch fenced code blocks")
    func bulletNormalizationSkipsFencedCodeBlocks() async throws {
        let service = Demark()
        let html = "<pre><code>* not a list\n+ also code</code></pre>"

        let markdown = try await service.convertToMarkdown(
            html,
            options: DemarkOptions(engine: .htmlToMd, bulletListMarker: "-")
        )

        #expect(markdown.contains("* not a list"))
        #expect(markdown.contains("+ also code"))
    }

    @Test("Fence-like code content does not end bullet protection", arguments: [
        "```", "~~~", "``` text", " ``` text", "    ```", "\t```",
    ])
    func bulletNormalizationPreservesFenceLikeCode(_ innerFence: String) async throws {
        let service = Demark()
        let code = "\(innerFence)\n* literal bullet\n+ another literal"
        let html = "<pre><code>\(code)</code></pre><ul><li>Real list</li></ul>"

        let markdown = try await service.convertToMarkdown(
            html,
            options: DemarkOptions(bulletListMarker: "-")
        )

        #expect(markdown.contains(code))
        #expect(markdown.hasSuffix("- Real list"))
    }

    @Test("Code nested in lists preserves literal bullets", arguments: [1, 2, 3])
    func bulletNormalizationPreservesNestedCode(_ depth: Int) async throws {
        let service = Demark()
        var html = "<pre><code>* literal bullet\n+ another literal</code></pre>"
        for _ in 0 ..< depth {
            html = "<ul><li><p>Parent</p>\(html)</li></ul>"
        }
        html += "<p>After code</p><ul><li>Real list</li></ul>"

        let markdown = try await service.convertToMarkdown(html)
        let lines = markdown.split(separator: "\n").map { $0.drop(while: { $0 == " " }) }

        #expect(lines.contains("* literal bullet"))
        #expect(lines.contains("+ another literal"))
        #expect(markdown.hasSuffix("- Real list"))
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
