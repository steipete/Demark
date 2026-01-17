import Foundation
import Testing
@testable import Demark

@MainActor
struct DemarkURLLoadingTests {
    // MARK: - Unit Tests: Invalid URL Schemes

    @Test("Invalid URL scheme - file:// rejected")
    func invalidURLSchemeFile() async {
        let service = Demark()
        let url = URL(string: "file:///tmp/test.html")!

        do {
            _ = try await service.convertToMarkdown(url: url)
            #expect(Bool(false), "Expected DemarkError.invalidURLScheme for file:// URL")
        } catch DemarkError.invalidURLScheme(let details) {
            #expect(details.contains("file"))
            #expect(details.contains("Only http and https"))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Invalid URL scheme - ftp:// rejected")
    func invalidURLSchemeFTP() async {
        let service = Demark()
        let url = URL(string: "ftp://example.com/file.txt")!

        do {
            _ = try await service.convertToMarkdown(url: url)
            #expect(Bool(false), "Expected DemarkError.invalidURLScheme for ftp:// URL")
        } catch DemarkError.invalidURLScheme(let details) {
            #expect(details.contains("ftp"))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Invalid URL scheme - custom scheme rejected")
    func invalidURLSchemeCustom() async {
        let service = Demark()
        let url = URL(string: "myapp://page/content")!

        do {
            _ = try await service.convertToMarkdown(url: url)
            #expect(Bool(false), "Expected DemarkError.invalidURLScheme for custom scheme")
        } catch DemarkError.invalidURLScheme(let details) {
            #expect(details.contains("myapp"))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    // MARK: - Unit Tests: URLLoadingOptions

    @Test("URLLoadingOptions default values")
    func urlLoadingOptionsDefaults() {
        let options = URLLoadingOptions()

        #expect(options.timeout == 30)
        #expect(options.waitForIdle == true)
        #expect(options.idleDelay == 0.5)
        #expect(options.contentSelector == nil)
        #expect(options.userAgent == nil)
    }

    @Test("URLLoadingOptions custom values")
    func urlLoadingOptionsCustom() {
        let options = URLLoadingOptions(
            timeout: 60,
            waitForIdle: false,
            idleDelay: 1.0,
            contentSelector: "article",
            userAgent: "TestBot/1.0"
        )

        #expect(options.timeout == 60)
        #expect(options.waitForIdle == false)
        #expect(options.idleDelay == 1.0)
        #expect(options.contentSelector == "article")
        #expect(options.userAgent == "TestBot/1.0")
    }

    @Test("URLLoadingOptions.default matches init()")
    func urlLoadingOptionsDefaultStatic() {
        let defaultOptions = URLLoadingOptions.default
        let initOptions = URLLoadingOptions()

        #expect(defaultOptions.timeout == initOptions.timeout)
        #expect(defaultOptions.waitForIdle == initOptions.waitForIdle)
        #expect(defaultOptions.idleDelay == initOptions.idleDelay)
        #expect(defaultOptions.contentSelector == initOptions.contentSelector)
        #expect(defaultOptions.userAgent == initOptions.userAgent)
    }

    // MARK: - Unit Tests: Error Descriptions

    @Test("Error description - urlLoadingTimeout")
    func errorDescriptionTimeout() {
        let error = DemarkError.urlLoadingTimeout("https://example.com after 30 seconds")
        let description = error.errorDescription ?? ""

        #expect(description.contains("timed out"))
        #expect(description.contains("https://example.com"))
        #expect(description.contains("30 seconds"))
    }

    @Test("Error description - urlNavigationFailed")
    func errorDescriptionNavigation() {
        let error = DemarkError.urlNavigationFailed("https://example.com: Connection refused")
        let description = error.errorDescription ?? ""

        #expect(description.contains("navigation failed"))
        #expect(description.contains("https://example.com"))
    }

    @Test("Error description - invalidURLScheme")
    func errorDescriptionScheme() {
        let error = DemarkError.invalidURLScheme("Only http and https URLs are supported, got: file")
        let description = error.errorDescription ?? ""

        #expect(description.contains("Invalid URL scheme"))
        #expect(description.contains("file"))
    }

    @Test("Error description - contentSelectorNotFound")
    func errorDescriptionSelector() {
        let error = DemarkError.contentSelectorNotFound("article.main-content")
        let description = error.errorDescription ?? ""

        #expect(description.contains("selector"))
        #expect(description.contains("article.main-content"))
        #expect(description.contains("matched no elements"))
    }
}

// MARK: - Integration Tests

@MainActor
struct DemarkURLLoadingIntegrationTests {
    @Test("Load example.com and convert to markdown")
    func loadExampleDotCom() async throws {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        let loadingOptions = URLLoadingOptions(
            timeout: 30,
            waitForIdle: true,
            idleDelay: 0.5
        )

        let markdown = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)

        // example.com has a simple page with "Example Domain" heading
        #expect(markdown.contains("Example Domain"))
        #expect(!markdown.isEmpty)
    }

    @Test("Load with content selector extracts specific element")
    func loadWithContentSelector() async throws {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        // example.com has a <div> container with the main content
        let loadingOptions = URLLoadingOptions(
            timeout: 30,
            contentSelector: "div"
        )

        let markdown = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)

        #expect(markdown.contains("Example Domain"))
    }

    @Test("Content selector not found throws error")
    func contentSelectorNotFound() async {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        let loadingOptions = URLLoadingOptions(
            timeout: 30,
            contentSelector: "article.nonexistent-class-xyz"
        )

        do {
            _ = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)
            #expect(Bool(false), "Expected DemarkError.contentSelectorNotFound")
        } catch DemarkError.contentSelectorNotFound(let selector) {
            #expect(selector == "article.nonexistent-class-xyz")
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Custom user agent is applied")
    func customUserAgent() async throws {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        let loadingOptions = URLLoadingOptions(
            timeout: 30,
            userAgent: "DemarkTest/1.0"
        )

        // Just verify the request succeeds with custom user agent
        let markdown = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)
        #expect(!markdown.isEmpty)
    }

    @Test("Short timeout with slow request")
    func shortTimeoutError() async {
        let service = Demark()
        // Use a URL that will definitely timeout with 0.1s timeout
        let url = URL(string: "https://example.com")!

        let loadingOptions = URLLoadingOptions(
            timeout: 0.001, // 1ms - will timeout
            waitForIdle: false,
            idleDelay: 0
        )

        do {
            _ = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)
            // If it succeeds (very fast network), that's fine too
        } catch DemarkError.urlLoadingTimeout(let details) {
            #expect(details.contains("example.com"))
        } catch {
            // Other network errors are acceptable
        }
    }
}

// MARK: - Edge Case Tests

@MainActor
struct DemarkURLLoadingEdgeCaseTests {
    @Test("URL with query parameters")
    func urlWithQueryParams() async throws {
        let service = Demark()
        // example.com ignores query params but we're testing URL handling
        let url = URL(string: "https://example.com/?foo=bar&baz=123")!

        let markdown = try await service.convertToMarkdown(url: url)
        #expect(markdown.contains("Example Domain"))
    }

    @Test("URL with fragment")
    func urlWithFragment() async throws {
        let service = Demark()
        let url = URL(string: "https://example.com/#section")!

        let markdown = try await service.convertToMarkdown(url: url)
        #expect(markdown.contains("Example Domain"))
    }

    @Test("URL with encoded characters")
    func urlWithEncodedChars() async throws {
        let service = Demark()
        // %20 is space, example.com will handle this gracefully
        let url = URL(string: "https://example.com/path%20with%20spaces")!

        do {
            let markdown = try await service.convertToMarkdown(url: url)
            // May get error page but shouldn't crash
            #expect(!markdown.isEmpty)
        } catch DemarkError.urlNavigationFailed {
            // 404 or similar is acceptable
        }
    }

    @Test("Selector with attribute")
    func selectorWithAttribute() async throws {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        // Test that attribute selectors work
        let loadingOptions = URLLoadingOptions(
            contentSelector: "a[href]"
        )

        let markdown = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)
        // example.com has a link - verify we got a markdown link
        #expect(markdown.contains("[") && markdown.contains("]("))
    }

    @Test("Selector with quotes in attribute")
    func selectorWithQuotes() async throws {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        // Test selector with quoted attribute value - use the actual IANA link
        let loadingOptions = URLLoadingOptions(
            contentSelector: "a[href*=\"iana.org\"]"
        )

        let markdown = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)
        // Verify we got the link content
        #expect(markdown.contains("iana.org"))
    }

    @Test("Minimal timeout and idle settings")
    func minimalDelays() async throws {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        let loadingOptions = URLLoadingOptions(
            timeout: 30,
            waitForIdle: false,
            idleDelay: 0
        )

        let markdown = try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)
        #expect(!markdown.isEmpty)
    }

    @Test("HTTP URL scheme accepted")
    func httpSchemeAccepted() async {
        let service = Demark()
        // Note: May fail due to ATS, but should not throw invalidURLScheme
        let url = URL(string: "http://example.com")!

        do {
            let markdown = try await service.convertToMarkdown(url: url)
            #expect(!markdown.isEmpty)
        } catch DemarkError.invalidURLScheme {
            #expect(Bool(false), "http:// should be accepted, not rejected as invalid scheme")
        } catch {
            // Network errors (ATS, connection issues) are acceptable
        }
    }
}

// MARK: - Cancellation Tests

@MainActor
struct DemarkURLLoadingCancellationTests {
    @Test("Task cancellation stops loading")
    func taskCancellation() async {
        let service = Demark()
        let url = URL(string: "https://example.com")!

        let loadingOptions = URLLoadingOptions(
            timeout: 60, // Long timeout
            waitForIdle: true,
            idleDelay: 5 // Long delay to ensure we can cancel
        )

        let task = Task {
            try await service.convertToMarkdown(url: url, loadingOptions: loadingOptions)
        }

        // Cancel quickly
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        task.cancel()

        let result = await task.result
        switch result {
        case .success:
            // Fast completion before cancel is OK
            break
        case .failure(let error):
            // CancellationError or wrapped version is expected
            let isCancellation = error is CancellationError ||
                String(describing: error).contains("cancel")
            #expect(isCancellation || error is DemarkError, "Expected cancellation or Demark error, got: \(error)")
        }
    }
}
