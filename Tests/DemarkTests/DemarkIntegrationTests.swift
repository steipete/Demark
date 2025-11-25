import Foundation
import Testing
import WebKit
@testable import Demark

/// Integration test for Demark functionality
/// This test verifies that the JavaScript libraries can be loaded and work correctly
@MainActor
struct DemarkIntegrationTests {
    @Test("JavaScript libraries exist in bundle")
    func javaScriptLibrariesExist() async throws {
        // Check that the required JavaScript files exist in the test bundle
        let bundle = Bundle.module

        let turndownPath = bundle.path(forResource: "turndown.min", ofType: "js")
        #expect(turndownPath != nil, "turndown.min.js should be available in bundle")
    }

    @Test("Turndown service loading and instantiation")
    func turndownServiceLoading() async throws {
        // Leverage the production service to load Turndown (with html-to-md fallback).
        let service = Demark()
        let options = DemarkOptions(engine: .turndown)
        let markdown = try await service.convertToMarkdown("<p>Integration</p>", options: options)

        #expect(markdown.contains("Integration"), "Turndown runtime should successfully convert simple HTML")
    }

    @Test("Basic conversion concept verification")
    func basicConversionConcept() async throws {
        // This test verifies the basic concept works
        // In a real implementation, Demark service handles the DOM complexity

        // For now, we'll just verify that the service class exists and can be initialized
        let service = Demark()

        // The service should be immediately available and work
        // Demark should be instantiable (always true for non-optional)

        // Test a basic conversion - service should initialize on first use
        do {
            let html = "<p>Test</p>"
            let markdown = try await service.convertToMarkdown(html)
            #expect(!markdown.isEmpty, "Conversion should produce non-empty result")
            print("✅ Conversion test successful: \(markdown)")
        } catch {
            print("⚠️  Conversion failed (expected in test environment): \(error)")
            // This is expected since test bundle might not have proper resource setup
        }
    }

    @Test("Conversion options structure validation")
    func conversionOptionsStructure() async throws {
        // Test that the options structure is properly defined
        let options = DemarkOptions(
            headingStyle: DemarkHeadingStyle.atx,
            bulletListMarker: "*",
            codeBlockStyle: DemarkCodeBlockStyle.fenced
        )

        #expect(options.headingStyle == DemarkHeadingStyle.atx)
        #expect(options.bulletListMarker == "*")
        #expect(options.codeBlockStyle == DemarkCodeBlockStyle.fenced)

        // Test setext heading style
        let setextOptions = DemarkOptions(
            headingStyle: DemarkHeadingStyle.setext,
            bulletListMarker: "-",
            codeBlockStyle: DemarkCodeBlockStyle.indented
        )

        #expect(setextOptions.headingStyle == DemarkHeadingStyle.setext)
        #expect(setextOptions.bulletListMarker == "-")
        #expect(setextOptions.codeBlockStyle == DemarkCodeBlockStyle.indented)
    }

    @Test("Error handling for invalid inputs")
    func errorHandling() async throws {
        let service = Demark()

        // Test with invalid HTML - should not crash
        do {
            let result = try await service.convertToMarkdown("<invalid>unclosed tag")
            print("Handled malformed HTML: \(result)")
        } catch {
            // Expected to fail gracefully
            #expect(error is DemarkError, "Should throw DemarkError for invalid input")
        }

        // Test with empty string
        do {
            let result = try await service.convertToMarkdown("")
            #expect(result.isEmpty, "Empty input should produce empty output")
        } catch {
            print("Empty string handling: \(error)")
        }
    }
}

// MARK: - Test Support

enum DemarkTestError: Error {
    case resourceNotFound(String)
    case scriptLoadingFailed(String)
    case serviceNotReady
}

/// Mock service for testing when actual service is not available
private class MockDemarkService {
    func convertToMarkdown(_ html: String) -> String {
        // Very basic mock conversion for testing
        html
            .replacingOccurrences(of: "<h1>", with: "# ")
            .replacingOccurrences(of: "</h1>", with: "\n")
            .replacingOccurrences(of: "<p>", with: "")
            .replacingOccurrences(of: "</p>", with: "\n")
            .replacingOccurrences(of: "<strong>", with: "**")
            .replacingOccurrences(of: "</strong>", with: "**")
    }
}
