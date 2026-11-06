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

    @Test("html-to-md keeps a break that arrived as CR LF")
    func htmlToMdKeepsCarriageReturnLineFeed() async throws {
        let service = Demark()
        let options = DemarkOptions(engine: .htmlToMd)

        let paragraph = try await service.convertToMarkdown("<p>Hello\r\nworld</p>", options: options)
        #expect(paragraph.contains("Hello"))
        #expect(paragraph.contains("world"))
        #expect(!paragraph.contains("Helloworld"))

        let pre = try await service.convertToMarkdown("<pre>one\r\ntwo</pre>", options: options)
        #expect(pre.contains("one"))
        #expect(pre.contains("two"))
        #expect(!pre.contains("onetwo"))
        #expect(pre.contains("one\ntwo") || pre.contains("one\r\ntwo"))

        let lineFeed = try await service.convertToMarkdown("<p>Hello\nworld</p>", options: options)
        #expect(lineFeed.contains("Hello"))
        #expect(lineFeed.contains("world"))
        #expect(!lineFeed.contains("Helloworld"))
    }
}
