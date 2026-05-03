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
}
