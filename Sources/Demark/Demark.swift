//
// Demark.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Foundation
import os.log

/// Main conversion runtime that routes between different engines
@MainActor
final class ConversionRuntime {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.demark", category: "conversion")
    private let turndownRuntime = TurndownRuntime()
    private let htmlToMdRuntime = HTMLToMdRuntime()
    private lazy var urlLoadingRuntime = URLLoadingRuntime()

    // MARK: - Public Methods

    /// Convert HTML to Markdown with optional configuration
    func htmlToMarkdown(_ html: String, options: DemarkOptions = .default) async throws -> String {
        logger.info(
            "Starting HTML to Markdown conversion with \(options.engine.rawValue) engine"
        )
        logger.info("Input length: \(html.count)")

        // Reject empty input early to keep error semantics consistent across engines.
        if html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw DemarkError.emptyResult
        }

        // Route to appropriate engine
        let rawMarkdown: String
        switch options.engine {
        case .turndown:
            do {
                rawMarkdown = try await turndownRuntime.convert(html, options: options)
            } catch {
                logger.warning("Turndown failed (\(error)); falling back to html-to-md")
                let fallback = DemarkOptions(
                    engine: .htmlToMd,
                    headingStyle: options.headingStyle,
                    bulletListMarker: options.bulletListMarker,
                    codeBlockStyle: options.codeBlockStyle,
                    skipTags: options.skipTags,
                    ignoreTags: options.ignoreTags,
                    emptyTags: options.emptyTags
                )
                rawMarkdown = try await htmlToMdRuntime.convert(html, options: fallback)
            }
        case .htmlToMd:
            rawMarkdown = try await htmlToMdRuntime.convert(html, options: options)
        }

        return normalizeMarkdown(rawMarkdown, bulletMarker: options.bulletListMarker)
    }

    /// Load URL and convert to Markdown
    func urlToMarkdown(_ url: URL, options: DemarkOptions, loadingOptions: URLLoadingOptions) async throws -> String {
        logger.info("Loading URL for conversion: \(url.absoluteString)")

        // Validate URL scheme
        guard url.scheme == "http" || url.scheme == "https" else {
            throw DemarkError.invalidURLScheme("Only http and https URLs are supported, got: \(url.scheme ?? "nil")")
        }

        // Load and extract HTML
        let html = try await urlLoadingRuntime.loadAndExtract(url: url, options: loadingOptions)

        // Convert using existing pipeline
        return try await htmlToMarkdown(html, options: options)
    }

    // MARK: - Normalization helpers

    /// Normalize list markers to match expectations in tests (single space after marker)
    /// without disturbing code blocks or other content.
    private func normalizeMarkdown(_ markdown: String, bulletMarker: String) -> String {
        guard bulletMarker.count == 1, let bulletMarker = bulletMarker.first, "-+*".contains(bulletMarker) else {
            return markdown
        }

        // Normalize unordered list markers (html-to-md currently always uses '*') and spacing,
        // while avoiding fenced code blocks and thematic breaks.
        guard let listItemRegex = try? NSRegularExpression(pattern: "^( {0,3})[*+\\-]\\s+(\\S)") else {
            return markdown
        }

        var inFencedCodeBlock = false
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        let normalized = lines.map { line -> String in
            let rawLine = String(line)

            let trimmedLeft = rawLine.drop(while: { $0 == " " || $0 == "\t" })
            if trimmedLeft.hasPrefix("```") || trimmedLeft.hasPrefix("~~~") {
                inFencedCodeBlock.toggle()
                return rawLine
            }

            guard !inFencedCodeBlock else {
                return rawLine
            }

            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let compact = trimmed.filter { $0 != " " && $0 != "\t" }
            if compact.count >= 3,
               let first = compact.first,
               "-*_".contains(first),
               compact.allSatisfy({ $0 == first })
            {
                return rawLine
            }

            let range = NSRange(rawLine.startIndex ..< rawLine.endIndex, in: rawLine)
            return listItemRegex.stringByReplacingMatches(
                in: rawLine,
                options: [],
                range: range,
                withTemplate: "$1\(bulletMarker) $2"
            )
        }

        return normalized.joined(separator: "\n")
    }
}

/// Service for converting HTML content to Markdown format.
///
/// Demark provides:
/// - Multiple conversion engines (Turndown.js and html-to-md)
/// - Main-thread HTML to Markdown conversion using WKWebView (Turndown)
/// - Background thread conversion using JavaScriptCore (html-to-md)
/// - Real browser DOM environment for complex HTML (Turndown)
/// - Fast string-based parsing for valid HTML (html-to-md)
/// - Native HTML parsing support
/// - Async/await interface
/// - Cross-platform support for all Apple platforms
///
/// ## Engine Selection
///
/// - **Turndown.js**: Full-featured, handles complex/malformed HTML, runs on main thread
/// - **html-to-md**: Lightweight and fast, best for valid HTML, runs on background thread
///
/// ## Platform Support
///
/// Demark works on all Apple platforms with WebKit support:
/// - **macOS 14.0+**: Full functionality with desktop optimizations
/// - **iOS 16.0+**: Full functionality with mobile optimizations
/// - **watchOS 10.0+**: Core functionality with minimal WebView
/// - **tvOS 17.0+**: Core functionality with TV-optimized WebView
/// - **visionOS 1.0+**: Full functionality with spatial computing optimizations
@MainActor
public final class Demark {
    // MARK: - Properties

    private let conversionRuntime: ConversionRuntime

    // MARK: - Lifecycle

    /// Create a new Demark converter instance.
    public init() {
        conversionRuntime = ConversionRuntime()
    }

    // MARK: - Public Methods

    /// Convert HTML content to Markdown format
    ///
    /// Takes HTML content as input and returns formatted Markdown using the selected engine.
    ///
    /// - Parameters:
    ///   - html: The HTML content to convert to Markdown
    ///   - options: Configuration options for the conversion process
    /// - Returns: The converted Markdown string
    /// - Throws: DemarkError if conversion fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let demark = Demark()
    /// let html = "<h1>Hello</h1><p>This is <strong>bold</strong> text.</p>"
    ///
    /// // Using default Turndown engine
    /// let markdown = try await demark.convertToMarkdown(html)
    /// // Result: "# Hello\n\nThis is **bold** text."
    ///
    /// // Using html-to-md for faster conversion
    /// let fastOptions = DemarkOptions(engine: .htmlToMd)
    /// let markdown = try await demark.convertToMarkdown(html, options: fastOptions)
    /// ```
    ///
    /// ## Threading
    ///
    /// - When using Turndown engine: Must be called from the main thread
    /// - When using html-to-md engine: Can be called from any thread, conversion happens on background thread
    ///
    /// ## Error Handling
    ///
    /// Common errors include:
    /// - `.jsEnvironmentInitializationFailed`: JavaScript runtime setup failed
    /// - `.libraryNotFound`: Required JavaScript library not found
    /// - `.conversionFailed`: The conversion process encountered an error
    /// - `.emptyResult`: Valid HTML produced empty Markdown
    ///
    /// ## See Also
    ///
    /// - `DemarkOptions`: Configuration options for conversion
    /// - `ConversionEngine`: Available conversion engines
    /// - `DemarkError`: Error types that can be thrown during conversion
    public func convertToMarkdown(_ html: String, options: DemarkOptions = DemarkOptions()) async throws -> String {
        try await conversionRuntime.htmlToMarkdown(html, options: options)
    }

    /// Convert a website URL to Markdown format
    ///
    /// Loads the URL in a WebView, waits for JavaScript execution to complete,
    /// extracts the rendered HTML, and converts it to Markdown.
    ///
    /// - Parameters:
    ///   - url: The URL to load and convert
    ///   - options: Configuration options for the HTML to Markdown conversion process
    ///   - loadingOptions: Configuration options for URL loading behavior
    /// - Returns: The converted Markdown string
    /// - Throws: DemarkError if loading or conversion fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let demark = Demark()
    /// let url = URL(string: "https://example.com")!
    ///
    /// // Basic usage with defaults
    /// let markdown = try await demark.convertToMarkdown(url: url)
    ///
    /// // Extract only article content with custom timeout
    /// let loadingOptions = URLLoadingOptions(
    ///     timeout: 60,
    ///     contentSelector: "article"
    /// )
    /// let markdown = try await demark.convertToMarkdown(
    ///     url: url,
    ///     loadingOptions: loadingOptions
    /// )
    /// ```
    ///
    /// ## Security
    ///
    /// Uses an ephemeral WebView with non-persistent storage for security.
    /// Each URL load creates a fresh WebView to prevent cookie/cache pollution.
    ///
    /// ## Network Requirements
    ///
    /// Plain HTTP URLs may require App Transport Security exceptions.
    /// Only `http` and `https` URL schemes are supported.
    ///
    /// ## See Also
    ///
    /// - `URLLoadingOptions`: Configuration options for URL loading
    /// - `DemarkOptions`: Configuration options for HTML to Markdown conversion
    /// - `DemarkError`: Error types that can be thrown during loading or conversion
    public func convertToMarkdown(
        url: URL,
        options: DemarkOptions = DemarkOptions(),
        loadingOptions: URLLoadingOptions = URLLoadingOptions()
    ) async throws -> String {
        try await conversionRuntime.urlToMarkdown(url, options: options, loadingOptions: loadingOptions)
    }
}
