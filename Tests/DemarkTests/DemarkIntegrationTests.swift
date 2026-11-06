//
// DemarkIntegrationTests.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Foundation
import Testing
@testable import Demark

@MainActor
struct DemarkIntegrationTests {
    @Test("JavaScript libraries exist in bundle")
    func javaScriptLibrariesExist() {
        let bundle = Bundle.module
        #expect(bundle.path(forResource: "turndown.min", ofType: "js") != nil)
        #expect(bundle.path(forResource: "html-to-md.min", ofType: "js") != nil)
    }

    @Test("Turndown conversion works")
    func turndownConversion() async throws {
        let service = Demark()
        let options = DemarkOptions(engine: .turndown)

        let markdown = try await service.convertToMarkdown("<p>Integration</p>", options: options)

        #expect(markdown.contains("Integration"))
    }

    @Test("html-to-md conversion works")
    func htmlToMdConversion() async throws {
        let service = Demark()
        let options = DemarkOptions(engine: .htmlToMd)

        let markdown = try await service.convertToMarkdown("<p>Integration</p>", options: options)

        #expect(markdown.contains("Integration"))
    }

    #if canImport(WebKit)
        @Test("a closing x-turndown tag does not drop the HTML tail")
        func closingXTurndownTagKeepsTail() async throws {
            let service = Demark()
            let options = DemarkOptions(engine: .turndown)
            let html = "<p>Hello</p></x-turndown><p>Tail</p>"

            let markdown = try await service.convertToMarkdown(html, options: options)

            #expect(markdown.contains("Hello"))
            #expect(markdown.contains("Tail"))

            let again = try await service.convertToMarkdown(
                "<p>Again</p></x-turndown><p>After</p>",
                options: options
            )
            #expect(again.contains("Again"))
            #expect(again.contains("After"))

            let upper = try await service.convertToMarkdown(
                "<p>Upper</p></X-TURNDOWN><p>Kept</p>",
                options: options
            )
            #expect(upper.contains("Upper"))
            #expect(upper.contains("Kept"))

            let titled = "<a href=\"https://example.com\" title=\"</x-turndown>\">Label</a><p>Tail</p>"
            let titledMarkdown = try await service.convertToMarkdown(titled, options: options)
            #expect(titledMarkdown.contains("Label"))
            #expect(titledMarkdown.contains("Tail"))
            #expect(titledMarkdown.contains("x-turndown"))
        }
    #endif
}
