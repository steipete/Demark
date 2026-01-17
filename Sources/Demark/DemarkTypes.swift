//
// DemarkTypes.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Foundation

// MARK: - Supporting Types

/// Heading conversion style for Markdown output.
public enum DemarkHeadingStyle: String, Sendable {
    case setext
    case atx
}

/// Code block formatting style for Markdown output.
public enum DemarkCodeBlockStyle: String, Sendable {
    case indented
    case fenced
}

/// Conversion engine to use for HTML to Markdown transformation
public enum ConversionEngine: String, Sendable {
    /// Turndown.js - Full featured, handles complex HTML well
    case turndown

    /// html-to-md - Lightweight and fast, best for valid HTML
    case htmlToMd
}

/// Conversion options for HTML to Markdown transformation
///
/// This struct provides configuration options that control how HTML elements are converted to Markdown.
/// Options are mapped to the appropriate JavaScript library based on the selected engine.
///
/// ## Basic Options
///
/// - `engine`: Conversion engine to use (Turndown.js or html-to-md)
/// - `headingStyle`: Controls how headings are converted (Turndown only)
/// - `bulletListMarker`: Sets the character used for unordered list items
/// - `codeBlockStyle`: Determines how code blocks are formatted (Turndown only)
///
/// ## Engine-Specific Options
///
/// - `skipTags`: Tags to skip (keep content, remove tag) - html-to-md feature mapped to Turndown
/// - `ignoreTags`: Tags to completely ignore (remove tag and content)
/// - `emptyTags`: Tags to render as empty (keep children only) - html-to-md only
///
/// ## Example Usage
///
/// ```swift
/// // Use default options with Turndown
/// let defaultOptions = DemarkOptions()
///
/// // Use html-to-md for faster conversion
/// let fastOptions = DemarkOptions(engine: .htmlToMd)
///
/// // Custom configuration
/// let customOptions = DemarkOptions(
///     engine: .turndown,
///     headingStyle: .setext,
///     bulletListMarker: "*",
///     codeBlockStyle: .indented
/// )
///
/// let markdown = try await demark.convertToMarkdown(html, options: customOptions)
/// ```
public struct DemarkOptions: Sendable {
    /// Default configuration with commonly used settings
    ///
    /// Provides a sensible default configuration:
    /// - ATX-style headings (`# Heading`)
    /// - Dash bullets (`- Item`)
    /// - Fenced code blocks (```)
    public static let `default` = DemarkOptions()

    /// Controls how HTML headings are converted to Markdown
    ///
    /// - `.atx`: Uses `#` prefix style (e.g., `# Heading 1`, `## Heading 2`)
    /// - `.setext`: Uses underline style for H1/H2 (e.g., `Heading\n=======`)
    ///
    /// **Default:** `.atx`
    ///
    /// **Turndown.js equivalent:** `headingStyle`
    public var headingStyle: DemarkHeadingStyle = .atx

    /// Character used for unordered list items
    ///
    /// Valid values: `"-"`, `"+"`, or `"*"`
    ///
    /// **Default:** `"-"`
    ///
    /// **Turndown.js equivalent:** `bulletListMarker`
    ///
    /// ## Examples
    /// - `"-"` produces: `- List item`
    /// - `"*"` produces: `* List item`
    /// - `"+"` produces: `+ List item`
    public var bulletListMarker: String = "-"

    /// Controls how code blocks are formatted in Markdown
    ///
    /// - `.fenced`: Uses triple backticks (```) for code blocks
    /// - `.indented`: Uses 4-space indentation for code blocks
    ///
    /// **Default:** `.fenced`
    ///
    /// **Turndown.js equivalent:** `codeBlockStyle`
    ///
    /// ## Examples
    /// - `.fenced`:
    ///   ```
    ///   ```javascript
    ///   console.log('hello');
    ///   ```
    ///   ```
    /// - `.indented`:
    ///   ```
    ///       console.log('hello');
    ///   ```
    public var codeBlockStyle: DemarkCodeBlockStyle = .fenced

    /// Conversion engine to use
    ///
    /// - `.turndown`: Full-featured, handles complex/malformed HTML well
    /// - `.htmlToMd`: Lightweight and fast, best for valid HTML
    ///
    /// **Default:** `.turndown`
    public var engine: ConversionEngine = .turndown

    /// Tags to skip (unwrap content, remove tag wrapper)
    ///
    /// These tags will be removed but their content will be preserved.
    /// Works with both engines.
    ///
    /// **Default:** `[]`
    public var skipTags: [String] = []

    /// Tags to completely ignore (remove tag and all content)
    ///
    /// These tags and all their content will be removed from output.
    /// Works with both engines.
    ///
    /// **Default:** `[]`
    public var ignoreTags: [String] = []

    /// Tags to render as empty (html-to-md only)
    ///
    /// These tags will be emptied but their children will be processed.
    /// Only works with html-to-md engine.
    ///
    /// **Default:** `[]`
    public var emptyTags: [String] = []

    /// Create a new options value with custom configuration.
    public init(
        engine: ConversionEngine = .turndown,
        headingStyle: DemarkHeadingStyle = .atx,
        bulletListMarker: String = "-",
        codeBlockStyle: DemarkCodeBlockStyle = .fenced,
        skipTags: [String] = [],
        ignoreTags: [String] = [],
        emptyTags: [String] = []
    ) {
        self.engine = engine
        self.headingStyle = headingStyle
        self.bulletListMarker = bulletListMarker
        self.codeBlockStyle = codeBlockStyle
        self.skipTags = skipTags
        self.ignoreTags = ignoreTags
        self.emptyTags = emptyTags
    }
}

// MARK: - URL Loading Options

/// Options for loading URLs in a WebView before conversion
///
/// Controls how Demark loads web pages, including timeout behavior,
/// JavaScript idle detection, and content extraction.
///
/// ## Example Usage
///
/// ```swift
/// // Basic usage with defaults
/// let markdown = try await demark.convertToMarkdown(url: url)
///
/// // Extract only article content with custom timeout
/// let options = URLLoadingOptions(
///     timeout: 60,
///     contentSelector: "article"
/// )
/// let markdown = try await demark.convertToMarkdown(url: url, loadingOptions: options)
/// ```
public struct URLLoadingOptions: Sendable {
    /// Default configuration with sensible settings
    public static let `default` = URLLoadingOptions()

    /// Maximum time to wait for page load (seconds)
    public var timeout: TimeInterval

    /// Wait for JavaScript to settle after page load
    public var waitForIdle: Bool

    /// Additional delay after page appears loaded (seconds)
    public var idleDelay: TimeInterval

    /// CSS selector to extract specific content (e.g., "article", "main")
    public var contentSelector: String?

    /// Custom user agent string
    public var userAgent: String?

    /// Create URL loading options with custom configuration
    ///
    /// - Parameters:
    ///   - timeout: Maximum time to wait for page load (default: 30 seconds)
    ///   - waitForIdle: Wait for JavaScript to settle after page load (default: true)
    ///   - idleDelay: Additional delay after page appears loaded (default: 0.5 seconds)
    ///   - contentSelector: CSS selector to extract specific content (default: nil, extracts full page)
    ///   - userAgent: Custom user agent string (default: nil, uses system default)
    public init(
        timeout: TimeInterval = 30,
        waitForIdle: Bool = true,
        idleDelay: TimeInterval = 0.5,
        contentSelector: String? = nil,
        userAgent: String? = nil
    ) {
        self.timeout = timeout
        self.waitForIdle = waitForIdle
        self.idleDelay = idleDelay
        self.contentSelector = contentSelector
        self.userAgent = userAgent
    }
}

// MARK: - Error Types

/// Errors that can occur during HTML to Markdown conversion.
public enum DemarkError: LocalizedError, Sendable {
    case jsEnvironmentInitializationFailed
    case libraryNotFound(String)
    case libraryLoadingFailed(String)
    case jsContextCreationFailed
    case turndownServiceCreationFailed
    case conversionFailed
    case emptyResult
    case invalidInput(String)
    case jsException(String)
    case bundleResourceMissing(String)
    case webViewInitializationFailed
    case urlLoadingTimeout(String)
    case urlNavigationFailed(String)
    case invalidURLScheme(String)
    case contentSelectorNotFound(String)

    // MARK: Public

    /// Human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case .jsEnvironmentInitializationFailed:
            "Failed to initialize JavaScript environment"
        case let .libraryNotFound(libraryName):
            "\(libraryName) library not found in bundle"
        case let .libraryLoadingFailed(details):
            "Failed to load JavaScript libraries: \(details)"
        case .jsContextCreationFailed:
            "Failed to create JavaScript context"
        case .turndownServiceCreationFailed:
            "Failed to create TurndownService instance"
        case .conversionFailed:
            "Failed to convert HTML to Markdown"
        case .emptyResult:
            "Conversion produced empty result"
        case let .invalidInput(details):
            "Invalid input provided: \(details)"
        case let .jsException(details):
            "JavaScript execution error: \(details)"
        case let .bundleResourceMissing(resource):
            "Required bundle resource missing: \(resource)"
        case .webViewInitializationFailed:
            "Failed to initialize WKWebView"
        case let .urlLoadingTimeout(details):
            "URL loading timed out: \(details)"
        case let .urlNavigationFailed(details):
            "URL navigation failed: \(details)"
        case let .invalidURLScheme(details):
            "Invalid URL scheme: \(details)"
        case let .contentSelectorNotFound(selector):
            "Content selector '\(selector)' matched no elements"
        }
    }
}
