//
// TurndownRuntime.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Foundation
import os.log

#if canImport(WebKit)
    import WebKit

    /// WKWebView-based HTML to Markdown conversion using Turndown.js
    ///
    /// This implementation uses WKWebView for proper DOM support:
    /// - Real browser DOM environment
    /// - Native HTML parsing
    /// - Turndown.js with full DOM support
    /// - Main thread execution required for WKWebView
    /// - Available where WebKit is available
    @MainActor
    final class TurndownRuntime {
        // MARK: - Properties

        private let logger = Logger(subsystem: "com.demark", category: "turndown")
        private var isInitialized = false
        private var initializationDelegate: InitializationNavigationDelegate?
        private var initializationTask: Task<Void, Error>?
        /// Strong reference to prevent garbage collection
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
            let escapedHTML = escapeHTML(htmlWithoutTurndownRootCloser(html))
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
                try await initializeIfNeeded()
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

                try await initializeIfNeeded()

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

        private func initializeIfNeeded() async throws {
            if let initializationTask {
                try await initializationTask.value
                return
            }

            let task = Task { @MainActor in
                try await self.initializeJavaScriptEnvironment()
            }
            initializationTask = task
            defer { initializationTask = nil }
            try await task.value
        }

        private func turndownIsAvailable(in webView: WKWebView) async throws -> Bool {
            do {
                let availability = try await webView.evaluateJavaScript("typeof window.TurndownService")
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

        /// Turndown wraps the input in `<x-turndown id="turndown-root">` and converts
        /// only that element. A closing tag in the caller HTML ends the wrapper early.
        /// Quoted attributes, comments, and raw text keep the same character sequence.
        private func htmlWithoutTurndownRootCloser(_ html: String) -> String {
            var output = ""
            output.reserveCapacity(html.count)
            var index = html.startIndex

            while index < html.endIndex {
                if html[index] == "<" {
                    if let end = skippedTurndownRootCloser(html, from: index) {
                        index = end
                        continue
                    }
                    index = appendMarkup(html, from: index, into: &output)
                    continue
                }
                output.append(html[index])
                index = html.index(after: index)
            }

            return output
        }

        private func skippedTurndownRootCloser(_ html: String, from index: String.Index) -> String.Index? {
            let token = "</x-turndown"
            guard let tokenEnd = html.index(index, offsetBy: token.count, limitedBy: html.endIndex),
                  html[index ..< tokenEnd].lowercased() == token,
                  isTagNameBoundary(html, at: tokenEnd) else { return nil }
            return endOfTag(html, from: index)
        }

        private func appendMarkup(_ html: String, from index: String.Index, into output: inout String) -> String.Index {
            if html[index...].hasPrefix("<!--") {
                if let end = commentEnd(in: html, from: index) {
                    output.append(contentsOf: html[index ..< end])
                    return end
                }
                output.append(contentsOf: html[index...])
                return html.endIndex
            }

            let next = html.index(after: index)
            guard next < html.endIndex else {
                output.append(html[index])
                return html.endIndex
            }

            let marker = html[next]
            let isEndTag = marker == "/"
            let isStartTag = marker.isASCII && marker.isLetter
            guard isEndTag || isStartTag || marker == "!" || marker == "?" else {
                output.append(html[index])
                return next
            }

            let nameIndex = isEndTag ? html.index(after: next) : next
            let name = tagName(in: html, from: nameIndex)
            let afterTag = appendTag(html, from: index, into: &output)
            if isStartTag, let name, isRawtextTag(name) {
                return appendRawtext(html, from: afterTag, endTag: name, into: &output)
            }
            return afterTag
        }

        private func appendRawtext(
            _ html: String,
            from index: String.Index,
            endTag name: String,
            into output: inout String
        ) -> String.Index {
            let token = "</\(name)"
            var cursor = index
            while cursor < html.endIndex {
                guard let match = html.range(
                    of: token,
                    options: .caseInsensitive,
                    range: cursor ..< html.endIndex
                ) else {
                    break
                }
                if isTagNameBoundary(html, at: match.upperBound) {
                    output.append(contentsOf: html[index ..< match.lowerBound])
                    return appendTag(html, from: match.lowerBound, into: &output)
                }
                guard let next = html.index(match.lowerBound, offsetBy: 1, limitedBy: html.endIndex) else {
                    break
                }
                cursor = next
            }
            output.append(contentsOf: html[index...])
            return html.endIndex
        }

        private func appendTag(_ html: String, from index: String.Index, into output: inout String) -> String.Index {
            guard let end = endOfTag(html, from: index) else {
                output.append(contentsOf: html[index...])
                return html.endIndex
            }
            output.append(contentsOf: html[index ..< end])
            return end
        }

        private func isAttributeQuote(_ character: Character) -> Bool {
            character == "\"" || character == "'"
        }

        /// Index just after the tag's closing `>`.
        /// A quote starts a value only after `=`. An unquoted value keeps `"` and `'` as text, and still ends at `>`.
        private func endOfTag(_ html: String, from index: String.Index) -> String.Index? {
            var cursor = index
            var quote: Character?
            var afterEquals = false
            var unquotedValue = false

            while cursor < html.endIndex {
                let character = html[cursor]
                cursor = html.index(after: cursor)

                if let activeQuote = quote {
                    if character == activeQuote {
                        quote = nil
                    }
                    continue
                }

                if afterEquals {
                    if isHTMLWhitespace(character) {
                        continue
                    }
                    afterEquals = false
                    if isAttributeQuote(character) {
                        quote = character
                        continue
                    }
                    unquotedValue = true
                }

                if unquotedValue {
                    if isHTMLWhitespace(character) {
                        unquotedValue = false
                        continue
                    }
                    if character == ">" {
                        return cursor
                    }
                    continue
                }

                if character == "=" {
                    afterEquals = true
                    continue
                }
                if character == ">" {
                    return cursor
                }
            }
            return nil
        }

        /// WebKit ends a comment at `-->`, `--!>`, an empty `<!-->`, or `<!--->`.
        private func commentEnd(in html: String, from index: String.Index) -> String.Index? {
            let marker = "<!--"
            guard html[index...].hasPrefix(marker),
                  let body = html.index(index, offsetBy: marker.count, limitedBy: html.endIndex)
            else { return nil }

            if body < html.endIndex, html[body] == ">" {
                return html.index(after: body)
            }
            if body < html.endIndex, html[body] == "-" {
                let afterDash = html.index(after: body)
                if afterDash < html.endIndex, html[afterDash] == ">" {
                    return html.index(after: afterDash)
                }
            }

            var cursor = body
            while cursor < html.endIndex {
                if html[cursor] == "-" {
                    let secondDash = html.index(after: cursor)
                    if secondDash < html.endIndex, html[secondDash] == "-" {
                        let afterDashes = html.index(after: secondDash)
                        if afterDashes < html.endIndex, html[afterDashes] == ">" {
                            return html.index(after: afterDashes)
                        }
                        if afterDashes < html.endIndex, html[afterDashes] == "!" {
                            let afterBang = html.index(after: afterDashes)
                            if afterBang < html.endIndex, html[afterBang] == ">" {
                                return html.index(after: afterBang)
                            }
                        }
                    }
                }
                cursor = html.index(after: cursor)
            }
            return nil
        }

        private func tagName(in html: String, from index: String.Index) -> String? {
            guard index < html.endIndex, html[index].isASCII, html[index].isLetter else { return nil }
            var cursor = index
            while cursor < html.endIndex, !isTagNameBoundary(html, at: cursor) {
                cursor = html.index(after: cursor)
            }
            return String(html[index ..< cursor])
        }

        private func isTagNameBoundary(_ html: String, at index: String.Index) -> Bool {
            guard index < html.endIndex else { return false }
            let boundary = html[index]
            return boundary == ">" || boundary == "/" || isHTMLWhitespace(boundary)
        }

        private func isRawtextTag(_ name: String) -> Bool {
            switch name.lowercased() {
            case "script", "style", "textarea", "title", "xmp":
                true
            default:
                false
            }
        }

        private func isHTMLWhitespace(_ character: Character) -> Bool {
            // Swift treats CR LF as one Character, so a boundary check has to accept that pair.
            !character.unicodeScalars.isEmpty && character.unicodeScalars.allSatisfy { scalar in
                switch scalar.value {
                case 0x09, 0x0a, 0x0c, 0x0d, 0x20:
                    true
                default:
                    false
                }
            }
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
                // Finish navigation before injecting the library so the page cannot replace
                // its JavaScript world and silently force conversion onto the fallback engine.
                try await loadBlankPage(in: webView)

                // Load Turndown library
                logger.info("Loading Turndown from: \(turndownPath)")
                let turndownScript = try String(contentsOfFile: turndownPath, encoding: .utf8)
                logger.info("Successfully read Turndown (\(turndownScript.count) characters)")

                // Load the Turndown library directly
                // Rollup's browser build keeps the constructor in a top-level binding that
                // WKWebView does not retain across evaluateJavaScript calls unless exported.
                let bootstrapScript = "\(turndownScript)\nwindow.TurndownService = TurndownService;\ntrue;"
                _ = try await webView.evaluateJavaScript(bootstrapScript)
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

        private func loadBlankPage(in webView: WKWebView) async throws {
            defer {
                webView.navigationDelegate = nil
                initializationDelegate = nil
            }

            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    let delegate = InitializationNavigationDelegate(
                        continuation: continuation,
                        onTimeout: { [weak webView] in webView?.stopLoading() }
                    )
                    initializationDelegate = delegate
                    webView.navigationDelegate = delegate
                    guard webView.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil) != nil else {
                        delegate.failToStart()
                        return
                    }
                }
            } onCancel: {
                Task { @MainActor in
                    webView.stopLoading()
                    self.initializationDelegate?.cancel()
                }
            }
        }
    }

    @MainActor
    final class InitializationNavigationDelegate: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Void, Error>?
        private var timeoutTask: Task<Void, Never>?

        init(
            continuation: CheckedContinuation<Void, Error>,
            timeout: Duration = .seconds(5),
            onTimeout: @escaping @MainActor @Sendable () -> Void
        ) {
            self.continuation = continuation
            super.init()
            timeoutTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                onTimeout()
                self?.complete(with: .failure(DemarkError.jsEnvironmentInitializationFailed))
            }
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            complete(with: .success(()))
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
            complete(with: .failure(DemarkError.jsEnvironmentInitializationFailed))
        }

        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
            complete(with: .failure(DemarkError.jsEnvironmentInitializationFailed))
        }

        func webViewWebContentProcessDidTerminate(_: WKWebView) {
            complete(with: .failure(DemarkError.jsEnvironmentInitializationFailed))
        }

        func failToStart() {
            complete(with: .failure(DemarkError.jsEnvironmentInitializationFailed))
        }

        func cancel() {
            complete(with: .failure(CancellationError()))
        }

        private func complete(with result: Result<Void, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            timeoutTask?.cancel()
            timeoutTask = nil
            continuation.resume(with: result)
        }
    }
#else
    @MainActor
    final class TurndownRuntime {
        func convert(_: String, options _: DemarkOptions) async throws -> String {
            throw DemarkError.runtimeUnavailable("Turndown requires WebKit, which is not available on this platform")
        }
    }
#endif
