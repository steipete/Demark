import Foundation
import os.log

/// Main conversion runtime that routes between different engines
@MainActor
final class ConversionRuntime: Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.demark", category: "conversion")
    private let turndownRuntime = TurndownRuntime()
    private let htmlToMdRuntime = HTMLToMdRuntime()

    // MARK: - Public Methods

    /// Convert HTML to Markdown with optional configuration
    func htmlToMarkdown(_ html: String, options: DemarkOptions = .default) async throws -> String {
        logger
            .info(
                "Starting HTML to Markdown conversion with \(options.engine.rawValue) engine (input length: \(html.count))"
            )

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

    // MARK: - Normalization helpers

    /// Normalize list markers to match expectations in tests (single space after marker)
    /// without disturbing code blocks or other content.
    private func normalizeMarkdown(_ markdown: String, bulletMarker: String) -> String {
        // Escape marker for regex usage
        let escaped = NSRegularExpression.escapedPattern(for: bulletMarker)
        let pattern = "^(\\s*\(escaped))\\s{2,}(\\S)" // marker + multiple spaces + content

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return markdown
        }

        let range = NSRange(markdown.startIndex ..< markdown.endIndex, in: markdown)
        return regex.stringByReplacingMatches(in: markdown, options: [], range: range, withTemplate: "$1 $2")
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
/// - **iOS 17.0+**: Full functionality with mobile optimizations
/// - **watchOS 10.0+**: Core functionality with minimal WebView
/// - **tvOS 17.0+**: Core functionality with TV-optimized WebView
/// - **visionOS 1.0+**: Full functionality with spatial computing optimizations
@MainActor
public final class Demark: Sendable {
    // MARK: - Properties

    private let conversionRuntime: ConversionRuntime

    // MARK: - Lifecycle

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
}
