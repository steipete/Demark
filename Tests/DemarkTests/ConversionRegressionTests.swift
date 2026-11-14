//
// ConversionRegressionTests.swift
// Demark
//
// Created by Peter Steinberger on 11/13/2026.
//

import Foundation
import Testing
@testable import Demark

@MainActor
struct ConversionRegressionTests {
    #if canImport(WebKit)
        @Test
        func skipTagPayloadIsInertAndOrdinaryTagsArePreserved() async throws {
            let options = DemarkOptions(
                engine: .turndown,
                headingStyle: .setext,
                skipTags: ["x-widget", "']); return 'owned'; //"]
            )
            let markdown = try await Demark().convertToMarkdown(
                "<h1>Heading</h1><x-widget>Preserved</x-widget>", options: options
            )
            #expect(markdown.contains("Heading\n======="))
            #expect(markdown.contains("<x-widget>Preserved</x-widget>"))
            #expect(!markdown.contains("owned"))
        }

        @Test
        func wrapperCloserKeepsTailAndRawText() async throws {
            let options = DemarkOptions(engine: .turndown, headingStyle: .setext)
            let markdown = try await Demark().convertToMarkdown(
                "<h1>Heading</h1></x-turndown><textarea>before </textareax> after</textarea><p>Tail</p>",
                options: options
            )
            #expect(markdown.contains("Heading\n======="))
            #expect(markdown.contains("before </textareax> after"))
            #expect(markdown.contains("Tail"))
            let raw = try await Demark().convertToMarkdown(
                "<xmp>literal </x-turndown> value</xmp><p>Tail</p>", options: options
            )
            #expect(raw.contains("literal </x-turndown> value"))
            #expect(raw.contains("Tail"))
        }
    #endif

    #if canImport(JavaScriptCore)
        @Test
        func htmlToMdRuntimeIsReleased() async throws {
            weak var reference: HTMLToMdRuntime?
            do {
                let runtime = HTMLToMdRuntime()
                reference = runtime
                let markdown = try await runtime.convert("<p>Hi</p>", options: DemarkOptions())
                #expect(markdown == "Hi")
            }
            let deadline = ContinuousClock.now.advanced(by: .milliseconds(500))
            while reference != nil, ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(reference == nil)
        }
    #endif
}
