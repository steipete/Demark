import XCTest
@testable import Demark

@MainActor
final class DemarkTests: XCTestCase {
    func testBasicHTMLToMarkdownConversion() async throws {
        let demark = Demark()
        let html = "<h1>Test Heading</h1><p>This is a <strong>test</strong> paragraph.</p>"

        let markdown = try await demark.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("# Test Heading"))
        XCTAssertTrue(markdown.contains("**test**"))
        XCTAssertTrue(markdown.contains("paragraph"))
    }

    func testHTMLToMdEngine() async throws {
        let demark = Demark()
        let html = "<h1>Test Heading</h1><p>This is a <strong>test</strong> paragraph with <em>emphasis</em>.</p>"
        let options = DemarkOptions(engine: .htmlToMd)

        let markdown = try await demark.convertToMarkdown(html, options: options)

        XCTAssertTrue(markdown.contains("# Test Heading"))
        XCTAssertTrue(markdown.contains("**test**"))
        XCTAssertTrue(markdown.contains("_emphasis_") || markdown.contains("*emphasis*"))
        XCTAssertTrue(markdown.contains("paragraph"))
    }

    func testEngineComparison() async throws {
        let demark = Demark()
        let html = "<h2>Subheading</h2><ul><li>Item 1</li><li>Item 2</li></ul>"

        // Test with Turndown
        let turndownOptions = DemarkOptions(engine: .turndown, bulletListMarker: "*")
        let turndownResult = try await demark.convertToMarkdown(html, options: turndownOptions)

        // Test with html-to-md
        let htmlToMdOptions = DemarkOptions(engine: .htmlToMd, bulletListMarker: "*")
        let htmlToMdResult = try await demark.convertToMarkdown(html, options: htmlToMdOptions)

        // Both should produce similar markdown
        print("Turndown result:\n\(turndownResult)")
        print("html-to-md result:\n\(htmlToMdResult)")

        XCTAssertTrue(turndownResult.contains("## Subheading"))
        XCTAssertTrue(htmlToMdResult.contains("## Subheading"))
        XCTAssertTrue(turndownResult.contains("Item 1"))
        XCTAssertTrue(htmlToMdResult.contains("Item 1"))
    }

    func testDemarkOptionsDefaults() {
        let options = DemarkOptions()

        XCTAssertEqual(options.engine, .turndown)
        XCTAssertEqual(options.headingStyle, .atx)
        XCTAssertEqual(options.bulletListMarker, "-")
        XCTAssertEqual(options.codeBlockStyle, .fenced)
        XCTAssertTrue(options.skipTags.isEmpty)
        XCTAssertTrue(options.ignoreTags.isEmpty)
        XCTAssertTrue(options.emptyTags.isEmpty)
    }

    func testCustomDemarkOptions() {
        let options = DemarkOptions(
            engine: .htmlToMd,
            headingStyle: .setext,
            bulletListMarker: "*",
            codeBlockStyle: .indented,
            skipTags: ["div", "span"],
            ignoreTags: ["script", "style"],
            emptyTags: ["br"]
        )

        XCTAssertEqual(options.engine, .htmlToMd)
        XCTAssertEqual(options.headingStyle, .setext)
        XCTAssertEqual(options.bulletListMarker, "*")
        XCTAssertEqual(options.codeBlockStyle, .indented)
        XCTAssertEqual(options.skipTags, ["div", "span"])
        XCTAssertEqual(options.ignoreTags, ["script", "style"])
        XCTAssertEqual(options.emptyTags, ["br"])
    }

    func testEmptyHTMLInput() async throws {
        let demark = Demark()
        let html = ""

        do {
            _ = try await demark.convertToMarkdown(html)
            XCTFail("Expected error for empty input")
        } catch DemarkError.emptyResult {
            // This is expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testListConversion() async throws {
        let demark = Demark()
        let html = "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>"

        let markdown = try await demark.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("- Item 1"))
        XCTAssertTrue(markdown.contains("- Item 2"))
        XCTAssertTrue(markdown.contains("- Item 3"))
    }

    func testCustomBulletMarker() async throws {
        let demark = Demark()
        let options = DemarkOptions(bulletListMarker: "*")
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"

        let markdown = try await demark.convertToMarkdown(html, options: options)

        XCTAssertTrue(markdown.contains("* Item 1"))
        XCTAssertTrue(markdown.contains("* Item 2"))
    }

    func testCodeBlockConversion() async throws {
        let demark = Demark()
        let html = "<pre><code>console.log('hello');</code></pre>"

        let markdown = try await demark.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("```"))
        XCTAssertTrue(markdown.contains("console.log('hello');"))
    }

    func testLinkConversion() async throws {
        let demark = Demark()
        let html = "<p>Visit <a href=\"https://example.com\">our website</a> for more info.</p>"

        let markdown = try await demark.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("[our website](https://example.com)"))
        XCTAssertTrue(markdown.contains("Visit"))
        XCTAssertTrue(markdown.contains("for more info"))
    }

    func testComplexHTMLStructure() async throws {
        let demark = Demark()
        let html = """
        <div>
            <h2>Features</h2>
            <ul>
                <li>Easy to use</li>
                <li>Fast conversion</li>
            </ul>
            <p>Learn more at <a href="https://github.com">GitHub</a>.</p>
        </div>
        """

        let markdown = try await demark.convertToMarkdown(html)

        XCTAssertTrue(markdown.contains("## Features"))
        XCTAssertTrue(markdown.contains("- Easy to use"))
        XCTAssertTrue(markdown.contains("- Fast conversion"))
        XCTAssertTrue(markdown.contains("[GitHub](https://github.com)"))
    }
}
