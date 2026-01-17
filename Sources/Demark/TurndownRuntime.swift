//
// TurndownRuntime.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Foundation
import os.log
import WebKit

/// WKWebView-based HTML to Markdown conversion using Turndown.js
///
/// This implementation uses WKWebView for proper DOM support:
/// - Real browser DOM environment
/// - Native HTML parsing
/// - Turndown.js with full DOM support
/// - Main thread execution required for WKWebView
/// - Cross-platform support (iOS, macOS, tvOS, watchOS, visionOS)
@MainActor
final class TurndownRuntime {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.demark", category: "turndown")
    private var isInitialized = false
    // Strong reference to prevent garbage collection
    private var webView: WKWebView?

    // MARK: - Lifecycle

    deinit {
        logger.info("TurndownRuntime being deallocated")
    }

    // MARK: - Public Methods

    /// Convert HTML to Markdown using Turndown.js
    func convert(_ html: String, options: DemarkOptions) async throws -> String {
        let webView = try await ensureWebViewReady()

        let optionsJSON = try buildOptionsJSON(options)
        let escapedHTML = escapeHTML(html)
        let skipTagsJS = buildSkipTagsJS(options.skipTags)
        let ignoreTagsJS = try buildIgnoreTagsJS(options.ignoreTags)
        let jsCode = buildConversionScript(
            escapedHTML: escapedHTML,
            optionsJSON: optionsJSON,
            skipTagsJS: skipTagsJS,
            ignoreTagsJS: ignoreTagsJS
        )

        logger.debug("Executing Turndown conversion...")

        do {
            let result = try await webView.evaluateJavaScript(jsCode)

            guard let markdown = result as? String else {
                logger.error("JavaScript result is not a string: \(type(of: result))")
                throw DemarkError.conversionFailed
            }

            logger.info("Turndown conversion completed (output length: \(markdown.count))")

            if markdown.isEmpty, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                logger.debug("Conversion resulted in empty markdown for non-empty HTML input.")
                throw DemarkError.emptyResult
            }

            logger.debug("Conversion successful, returning result")
            return markdown
        } catch {
            logger.error("JavaScript exception during conversion: \(error)")
            throw DemarkError.jsException(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func ensureWebViewReady() async throws -> WKWebView {
        if !isInitialized {
            logger.info("WKWebView environment not initialized, initializing now...")
            try await initializeJavaScriptEnvironment()
        }

        guard let webView else {
            logger.error("WKWebView not available")
            throw DemarkError.webViewInitializationFailed
        }

        guard try await turndownIsAvailable(in: webView) else {
            logger.warning("TurndownService missing, reinitializing WKWebView...")

            // Clean up old WebView before creating new one
            self.webView = nil
            isInitialized = false

            try await initializeJavaScriptEnvironment()

            guard let refreshedWebView = self.webView else {
                throw DemarkError.jsEnvironmentInitializationFailed
            }

            // Verify TurndownService is available after reinit
            guard try await turndownIsAvailable(in: refreshedWebView) else {
                logger.error("TurndownService still not available after reinitialization")
                throw DemarkError.jsEnvironmentInitializationFailed
            }

            return refreshedWebView
        }

        return webView
    }

    private func turndownIsAvailable(in webView: WKWebView) async throws -> Bool {
        do {
            let availability = try await webView.evaluateJavaScript("typeof TurndownService")
            guard let type = availability as? String else { return false }
            return type == "function"
        } catch {
            logger.warning("Failed to check TurndownService availability: \(error)")
            return false
        }
    }

    private func buildOptionsJSON(_ options: DemarkOptions) throws -> String {
        let optionsDict: [String: Any] = [
            "headingStyle": options.headingStyle.rawValue,
            "hr": "---",
            "bulletListMarker": options.bulletListMarker,
            "codeBlockStyle": options.codeBlockStyle.rawValue,
            "fence": "```",
            "emDelimiter": "_",
            "strongDelimiter": "**",
            "linkStyle": "inlined",
            "linkReferenceStyle": "full",
        ]

        let optionsData = try JSONSerialization.data(withJSONObject: optionsDict)
        guard let optionsString = String(data: optionsData, encoding: .utf8) else {
            throw DemarkError.invalidInput("Failed to serialize options")
        }
        return optionsString
    }

    private func escapeHTML(_ html: String) -> String {
        html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func buildSkipTagsJS(_ skipTags: [String]) -> String {
        guard !skipTags.isEmpty else { return "" }
        let keepCalls = skipTags.map { "turndownService.keep(['\($0)']);" }
        return keepCalls.joined(separator: "\n")
    }

    private func buildIgnoreTagsJS(_ ignoreTags: [String]) throws -> String {
        guard !ignoreTags.isEmpty else { return "" }
        let ignoreTagsJSON = try JSONSerialization.data(withJSONObject: ignoreTags)
        let ignoreTagsString = String(data: ignoreTagsJSON, encoding: .utf8) ?? "[]"
        return "turndownService.remove(\(ignoreTagsString));"
    }

    private func buildConversionScript(
        escapedHTML: String,
        optionsJSON: String,
        skipTagsJS: String,
        ignoreTagsJS: String
    ) -> String {
        """
        (function() {
            try {
                // Find TurndownService constructor
                var TurndownConstructor = null;
                if (typeof TurndownService !== 'undefined') {
                    TurndownConstructor = TurndownService;
                } else if (typeof window.TurndownService !== 'undefined') {
                    TurndownConstructor = window.TurndownService;
                } else {
                    throw new Error('TurndownService is not available');
                }
                // Create TurndownService with options
                var turndownService = new TurndownConstructor(\(optionsJSON));
                // Configure service
                turndownService.keep(['del', 'ins', 'sup', 'sub']);
                turndownService.remove(['script', 'style']);
                // Apply custom skip/ignore rules
                \(skipTagsJS)
                \(ignoreTagsJS)
                // Convert HTML to Markdown
                var markdown = turndownService.turndown("\(escapedHTML)");
                // Return result
                return markdown;
            } catch (error) {
                throw new Error('Conversion failed: ' + error.message);
            }
        })();
        """
    }

    // MARK: - Private Methods

    private func initializeJavaScriptEnvironment() async throws {
        logger.info("Initializing WKWebView environment for HTML to Markdown conversion")

        // Create WKWebView configuration
        let config = WKWebViewConfiguration()
        config.userContentController = WKUserContentController()

        // Platform-specific configuration
        #if os(macOS)
            // macOS-specific optimizations
            config.preferences.javaScriptCanOpenWindowsAutomatically = false
        #elseif os(iOS) || os(visionOS)
            // iOS/visionOS-specific optimizations
            config.allowsInlineMediaPlayback = false
            config.mediaTypesRequiringUserActionForPlayback = .all
        #endif

        // Create WKWebView with appropriate frame
        #if os(watchOS) || os(tvOS)
            // For watchOS and tvOS, use minimal frame
            webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), configuration: config)
        #else
            // For iOS, macOS, visionOS
            webView = WKWebView(frame: .zero, configuration: config)
        #endif
        guard webView != nil else {
            logger.error("Failed to create WKWebView")
            throw DemarkError.webViewInitializationFailed
        }
        logger.info("Successfully created WKWebView")

        // Load JavaScript libraries
        try await loadJavaScriptLibraries()
    }

    private func loadJavaScriptLibraries() async throws {
        logger.info("Loading JavaScript libraries into WKWebView")

        guard let webView else {
            throw DemarkError.webViewInitializationFailed
        }

        // Find JavaScript library using helper
        guard let turndownPath = BundleResourceHelper.findJavaScriptResource(
            named: "turndown.min",
            classForBundle: TurndownRuntime.self
        ) else {
            logger.error("turndown.min.js not found in any bundle")
            throw DemarkError.libraryNotFound("turndown.min.js")
        }

        logger.info("Found turndown.min.js at: \(turndownPath)")

        do {
            // Load a blank page first
            webView.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)

            // Wait for page to actually be ready (poll document.readyState)
            try await waitForDocumentReady(webView: webView)

            // Load Turndown library
            logger.info("Loading Turndown from: \(turndownPath)")
            let turndownScript = try String(contentsOfFile: turndownPath, encoding: .utf8)
            logger.info("Successfully read Turndown (\(turndownScript.count) characters)")

            // Load the Turndown library directly
            _ = try await webView.evaluateJavaScript(turndownScript)
            logger.info("Successfully loaded Turndown JavaScript library")

            // Verify TurndownService is actually available
            guard try await turndownIsAvailable(in: webView) else {
                logger.error("TurndownService not available after loading script")
                throw DemarkError.libraryLoadingFailed("TurndownService not available in global scope")
            }

            isInitialized = true
            logger.info("WKWebView runtime ready with Turndown")
        } catch let error as DemarkError {
            throw error
        } catch {
            logger.error("Failed to load JavaScript libraries: \(error)")
            throw DemarkError.libraryLoadingFailed(error.localizedDescription)
        }
    }

    /// Wait for document to be ready by polling document.readyState
    private func waitForDocumentReady(webView: WKWebView) async throws {
        let maxAttempts = 50 // 5 seconds max
        var attempts = 0

        while attempts < maxAttempts {
            try Task.checkCancellation()

            do {
                let readyState = try await webView.evaluateJavaScript("document.readyState") as? String
                logger.debug("Document readyState: \(readyState ?? "unknown")")
                if readyState == "complete" || readyState == "interactive" {
                    return
                }
            } catch {
                // If we can't even evaluate JS, the page isn't ready yet
                logger.debug("Waiting for document... (\(error.localizedDescription))")
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms between polls
            attempts += 1
        }

        logger.warning("Document never reached ready state, proceeding anyway")
    }
}
