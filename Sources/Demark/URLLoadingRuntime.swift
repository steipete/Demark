//
// URLLoadingRuntime.swift
// Demark
//
// Copyright © 2026 atacan. All rights reserved.
//

import Foundation
import os.log
import WebKit

/// WebView-based URL loading runtime for fetching JavaScript-rendered content
///
/// This implementation uses WKWebView to load URLs and extract rendered HTML:
/// - Real browser DOM environment
/// - JavaScript execution and rendering
/// - Ephemeral storage for security isolation
/// - Main thread execution required for WKWebView
/// - Cross-platform support (iOS, macOS, tvOS, watchOS, visionOS)
@MainActor
final class URLLoadingRuntime {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.demark", category: "url-loading")
    private var activeDelegates: [ObjectIdentifier: URLNavigationDelegate] = [:]

    // MARK: - Lifecycle

    deinit {
        logger.info("URLLoadingRuntime being deallocated")
    }

    // MARK: - Public Methods

    /// Load a URL in a WebView and extract rendered HTML
    ///
    /// Creates an ephemeral WebView for each load to ensure isolation between
    /// untrusted pages. Supports waiting for JavaScript to settle and extracting
    /// specific content via CSS selectors.
    ///
    /// This method supports concurrent calls - each invocation uses its own webView
    /// and cleanup is isolated to that specific request.
    ///
    /// - Parameters:
    ///   - url: The URL to load
    ///   - options: Loading configuration options
    /// - Returns: The rendered HTML content
    /// - Throws: DemarkError if loading fails
    func loadAndExtract(url: URL, options: URLLoadingOptions) async throws -> String {
        // Create fresh ephemeral WebView for each load
        let webView = createWebView(userAgent: options.userAgent)

        defer {
            webView.stopLoading()
            self.activeDelegates.removeValue(forKey: ObjectIdentifier(webView))
        }

        return try await withTaskCancellationHandler {
            try await performLoad(webView: webView, url: url, options: options)
        } onCancel: {
            Task { @MainActor in
                webView.stopLoading()
                if let delegate = self.activeDelegates[ObjectIdentifier(webView)] {
                    delegate.cancel()
                }
            }
        }
    }

    // MARK: - Private Methods

    private func createWebView(userAgent: String?) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController = WKUserContentController()

        // Use ephemeral storage - no cookies/cache pollution between loads
        config.websiteDataStore = .nonPersistent()

        // Platform-specific configuration
        #if os(macOS)
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        #elseif os(iOS) || os(visionOS)
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        #endif

        let webView: WKWebView
        #if os(watchOS) || os(tvOS)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), configuration: config)
        #else
        webView = WKWebView(frame: .zero, configuration: config)
        #endif

        // Set user agent before loading
        if let userAgent {
            webView.customUserAgent = userAgent
        }

        return webView
    }

    private func performLoad(webView: WKWebView, url: URL, options: URLLoadingOptions) async throws -> String {
        try Task.checkCancellation()

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = URLNavigationDelegate(
                url: url,
                options: options,
                logger: logger,
                continuation: continuation
            )
            self.activeDelegates[ObjectIdentifier(webView)] = delegate
            webView.navigationDelegate = delegate

            let request = URLRequest(url: url)
            webView.load(request)

            // Set up timeout (delegate will cancel this task on completion)
            if let nanoseconds = clampedNanoseconds(options.timeout) {
                delegate.timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: nanoseconds)
                    delegate.handleTimeout()
                }
            }
        }
    }
}

// MARK: - Navigation Delegate

@MainActor
private final class URLNavigationDelegate: NSObject, WKNavigationDelegate {
    private let url: URL
    private let options: URLLoadingOptions
    private let logger: Logger
    private var continuation: CheckedContinuation<String, Error>?
    private var hasCompleted = false

    /// Timeout task - cancelled on successful completion to prevent leaks
    var timeoutTask: Task<Void, Never>?

    init(url: URL, options: URLLoadingOptions, logger: Logger, continuation: CheckedContinuation<String, Error>) {
        self.url = url
        self.options = options
        self.logger = logger
        self.continuation = continuation
        super.init()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("Navigation finished for: \(self.url.absoluteString)")

        Task { @MainActor in
            do {
                try Task.checkCancellation()

                if options.waitForIdle {
                    try await waitForIdle(webView: webView)
                }

                if let nanoseconds = clampedNanoseconds(options.idleDelay), nanoseconds > 0 {
                    try await Task.sleep(nanoseconds: nanoseconds)
                }

                try Task.checkCancellation()
                let html = try await extractHTML(from: webView)
                complete(with: .success(html))
            } catch {
                complete(with: .failure(error))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("Navigation failed: \(error.localizedDescription)")
        complete(with: .failure(DemarkError.urlNavigationFailed("\(url.absoluteString): \(error.localizedDescription)")))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("Provisional navigation failed: \(error.localizedDescription)")
        complete(with: .failure(DemarkError.urlNavigationFailed("\(url.absoluteString): \(error.localizedDescription)")))
    }

    func handleTimeout() {
        guard !hasCompleted else { return }
        logger.warning("Page load timed out for: \(self.url.absoluteString)")
        let secondsDescription: String
        if let nanoseconds = clampedNanoseconds(options.timeout) {
            secondsDescription = String(nanoseconds / 1_000_000_000)
        } else {
            secondsDescription = "∞"
        }
        complete(with: .failure(DemarkError.urlLoadingTimeout("\(url.absoluteString) after \(secondsDescription) seconds")))
    }

    func cancel() {
        guard !hasCompleted else { return }
        complete(with: .failure(CancellationError()))
    }

    private func waitForIdle(webView: WKWebView) async throws {
        var attempts = 0
        let maxAttempts = 50 // 5 seconds max polling

        while attempts < maxAttempts {
            try Task.checkCancellation()
            let readyState = try await webView.evaluateJavaScript("document.readyState") as? String
            logger.debug("Document readyState: \(readyState ?? "unknown")")
            if readyState == "complete" {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }
        logger.warning("Document never reached 'complete' state, proceeding anyway")
    }

    private func extractHTML(from webView: WKWebView) async throws -> String {
        let script: String
        if let selector = options.contentSelector {
            // Use JSON serialization for proper escaping (handles quotes, newlines, special chars)
            let escapedSelector = try escapeForJS(selector)
            script = """
            (function() {
                var el = document.querySelector(\(escapedSelector));
                return el ? el.outerHTML : null;
            })();
            """
        } else {
            script = "document.documentElement.outerHTML"
        }

        let result = try await webView.evaluateJavaScript(script)

        if options.contentSelector != nil, result == nil || (result as? NSNull) != nil {
            throw DemarkError.contentSelectorNotFound(options.contentSelector!)
        }

        guard let html = result as? String else {
            throw DemarkError.conversionFailed
        }

        logger.info("Extracted HTML length: \(html.count) characters")
        return html
    }

    /// Escape string for JavaScript using JSON serialization (handles all special characters)
    private func escapeForJS(_ string: String) throws -> String {
        // Wrap in array since JSONSerialization requires a collection as top-level object
        let data = try JSONSerialization.data(withJSONObject: [string])
        guard let arrayString = String(data: data, encoding: .utf8) else {
            throw DemarkError.invalidInput("Failed to escape selector: \(string)")
        }
        // Extract the quoted string from the array: ["value"] -> "value"
        let startIndex = arrayString.index(after: arrayString.startIndex) // Skip [
        let endIndex = arrayString.index(before: arrayString.endIndex) // Skip ]
        return String(arrayString[startIndex ..< endIndex])
    }

    private func complete(with result: Result<String, Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true

        // Cancel timeout task to prevent leak
        timeoutTask?.cancel()
        timeoutTask = nil

        switch result {
        case let .success(html): continuation?.resume(returning: html)
        case let .failure(error): continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

private func clampedNanoseconds(_ seconds: TimeInterval) -> UInt64? {
    guard seconds.isFinite else { return nil }
    let maxSeconds = Double(UInt64.max) / 1_000_000_000
    let clampedSeconds = max(0, min(seconds, maxSeconds))
    return UInt64(clampedSeconds * 1_000_000_000)
}
