//
// DemarkTests.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Testing
@testable import Demark

@MainActor
struct DemarkTests {
    @Test("Basic HTML to Markdown conversion")
    func basicHTMLToMarkdownConversion() async throws {
        let demark = Demark()
        let html = "<h1>Test Heading</h1><p>This is a <strong>test</strong> paragraph.</p>"

        let markdown = try await demark.convertToMarkdown(html)

        #expect(markdown.contains("# Test Heading"))
        #expect(markdown.contains("**test**"))
        #expect(markdown.contains("paragraph"))
    }

    @Test("html-to-md engine conversion")
    func htmlToMdEngine() async throws {
        let demark = Demark()
        let html = "<h1>Test Heading</h1><p>This is a <strong>test</strong> paragraph with <em>emphasis</em>.</p>"
        let options = DemarkOptions(engine: .htmlToMd)

        let markdown = try await demark.convertToMarkdown(html, options: options)

        #expect(markdown.contains("# Test Heading"))
        #expect(markdown.contains("**test**"))
        #expect(markdown.contains("_emphasis_") || markdown.contains("*emphasis*"))
        #expect(markdown.contains("paragraph"))
    }

    @Test("Engine comparison")
    func engineComparison() async throws {
        let demark = Demark()
        let html = "<h2>Subheading</h2><ul><li>Item 1</li><li>Item 2</li></ul>"

        let turndownOptions = DemarkOptions(engine: .turndown, bulletListMarker: "*")
        let turndownResult = try await demark.convertToMarkdown(html, options: turndownOptions)

        let htmlToMdOptions = DemarkOptions(engine: .htmlToMd, bulletListMarker: "*")
        let htmlToMdResult = try await demark.convertToMarkdown(html, options: htmlToMdOptions)

        print("Turndown result:\n\(turndownResult)")
        print("html-to-md result:\n\(htmlToMdResult)")

        #expect(turndownResult.contains("## Subheading"))
        #expect(htmlToMdResult.contains("## Subheading"))
        #expect(turndownResult.contains("Item 1"))
        #expect(htmlToMdResult.contains("Item 1"))
    }

    @Test("Default Demark options")
    func demarkOptionsDefaults() {
        let options = DemarkOptions()

        #expect(options.engine == .turndown)
        #expect(options.headingStyle == .atx)
        #expect(options.bulletListMarker == "-")
        #expect(options.codeBlockStyle == .fenced)
        #expect(options.skipTags.isEmpty)
        #expect(options.ignoreTags.isEmpty)
        #expect(options.emptyTags.isEmpty)
    }

    @Test("Custom Demark options")
    func customDemarkOptions() {
        let options = DemarkOptions(
            engine: .htmlToMd,
            headingStyle: .setext,
            bulletListMarker: "*",
            codeBlockStyle: .indented,
            skipTags: ["div", "span"],
            ignoreTags: ["script", "style"],
            emptyTags: ["br"]
        )

        #expect(options.engine == .htmlToMd)
        #expect(options.headingStyle == .setext)
        #expect(options.bulletListMarker == "*")
        #expect(options.codeBlockStyle == .indented)
        #expect(options.skipTags == ["div", "span"])
        #expect(options.ignoreTags == ["script", "style"])
        #expect(options.emptyTags == ["br"])
    }

    @Test("Empty HTML input")
    func emptyHTMLInput() async throws {
        let demark = Demark()
        let html = ""

        do {
            _ = try await demark.convertToMarkdown(html)
            #expect(Bool(false), "Expected error for empty input")
        } catch DemarkError.emptyResult {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("List conversion")
    func listConversion() async throws {
        let demark = Demark()
        let html = "<ul><li>Item 1</li><li>Item 2</li><li>Item 3</li></ul>"

        let markdown = try await demark.convertToMarkdown(html)

        #expect(markdown.contains("- Item 1") || markdown.contains("* Item 1"))
        #expect(markdown.contains("- Item 2") || markdown.contains("* Item 2"))
        #expect(markdown.contains("- Item 3") || markdown.contains("* Item 3"))
    }

    @Test("Custom bullet marker")
    func customBulletMarker() async throws {
        let demark = Demark()
        let options = DemarkOptions(bulletListMarker: "*")
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"

        let markdown = try await demark.convertToMarkdown(html, options: options)

        #expect(markdown.contains("* Item 1"))
        #expect(markdown.contains("* Item 2"))
    }

    @Test("Code block conversion")
    func codeBlockConversion() async throws {
        let demark = Demark()
        let html = "<pre><code>console.log('hello');</code></pre>"

        let markdown = try await demark.convertToMarkdown(html)

        #expect(markdown.contains("```"))
        #expect(markdown.contains("console.log('hello');"))
    }

    @Test("Link conversion")
    func linkConversion() async throws {
        let demark = Demark()
        let html = "<p>Visit <a href=\"https://example.com\">our website</a> for more info.</p>"

        let markdown = try await demark.convertToMarkdown(html)

        #expect(markdown.contains("[our website](https://example.com)"))
        #expect(markdown.contains("Visit"))
        #expect(markdown.contains("for more info"))
    }

    @Test("Complex HTML structure")
    func complexHTMLStructure() async throws {
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

        #expect(markdown.contains("## Features"))
        #expect(markdown.contains("- Easy to use") || markdown.contains("* Easy to use"))
        #expect(markdown.contains("- Fast conversion") || markdown.contains("* Fast conversion"))
        #expect(markdown.contains("[GitHub](https://github.com)"))
    }
}
