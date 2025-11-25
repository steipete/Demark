import Foundation
import JavaScriptCore
import os.log

/// JSCore-based HTML to Markdown conversion for html-to-md
///
/// This implementation uses JavaScriptCore for fast, lightweight conversion:
/// - Runs on background thread for performance
/// - No DOM required (string-based parsing)
/// - Best for valid HTML
/// - Cross-platform support
/// - Thread-safe: All JSContext access happens on a single serial queue
final class HTMLToMdRuntime: @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.demark", category: "html-to-md")
    private var jsContext: JSContext?
    private let queue = DispatchQueue(label: "com.demark.html-to-md", qos: .userInitiated)
    private var isInitialized = false

    // MARK: - Public Methods

    /// Convert HTML to Markdown using html-to-md
    /// All operations happen on the dedicated queue to ensure thread safety
    func convert(_ html: String, options: DemarkOptions) async throws -> String {
        // First ensure we're initialized
        if await !isInitializedAsync() {
            try await initialize()
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self,
                      let context = self.jsContext
                else {
                    continuation.resume(throwing: DemarkError.jsContextCreationFailed)
                    return
                }

                // Build html-to-md options
                var optionsDict: [String: Any] = [:]

                // Map common options
                if !options.skipTags.isEmpty {
                    optionsDict["skipTags"] = options.skipTags
                }
                if !options.ignoreTags.isEmpty {
                    optionsDict["ignoreTags"] = options.ignoreTags
                }
                if !options.emptyTags.isEmpty {
                    optionsDict["emptyTags"] = options.emptyTags
                }

                // html-to-md doesn't have bulletListMarker, it uses bulletMarker
                if options.bulletListMarker != "-" {
                    optionsDict["bulletMarker"] = options.bulletListMarker
                }

                do {
                    // Convert options to JSON
                    let optionsData = try JSONSerialization.data(withJSONObject: optionsDict)
                    guard let optionsJSON = String(data: optionsData, encoding: .utf8) else {
                        throw DemarkError.invalidInput("Failed to serialize options")
                    }

                    // Escape HTML for JavaScript
                    let escapedHTML = html
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "`", with: "\\`")
                        .replacingOccurrences(of: "$", with: "\\$")

                    // Call html-to-md (using html2md function name)
                    let script = """
                    (function() {
                        try {
                            return html2md(`\(escapedHTML)`, \(optionsJSON));
                        } catch (error) {
                            throw new Error('Conversion failed: ' + error.message);
                        }
                    })();
                    """

                    guard let result = context.evaluateScript(script),
                          !result.isUndefined,
                          let markdown = result.toString()
                    else {
                        throw DemarkError.conversionFailed
                    }

                    self.logger.info("html-to-md conversion completed")
                    continuation.resume(returning: markdown)

                } catch {
                    self.logger.error("Conversion error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Initialize the JSCore runtime with html-to-md
    /// This method ensures initialization happens only once and on the correct queue
    private func initialize() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: DemarkError.jsContextCreationFailed)
                    return
                }

                // Check if already initialized on the queue
                if self.isInitialized {
                    continuation.resume()
                    return
                }

                do {
                    // Create JavaScript context
                    guard let context = JSContext() else {
                        throw DemarkError.jsContextCreationFailed
                    }

                    // Set up error handling
                    context.exceptionHandler = { _, exception in
                        if let error = exception?.toString() {
                            self.logger.error("JS Exception: \(error)")
                        }
                    }

                    // Load html-to-md library using helper
                    guard let path = BundleResourceHelper.findJavaScriptResource(
                        named: "html-to-md.min",
                        classForBundle: HTMLToMdRuntime.self
                    ) else {
                        throw DemarkError.libraryNotFound("html-to-md.min.js")
                    }

                    let script = try String(contentsOfFile: path, encoding: .utf8)
                    context.evaluateScript(script)

                    // Verify html-to-md is loaded (it exports as html2md)
                    guard let html2md = context.objectForKeyedSubscript("html2md"),
                          !html2md.isUndefined
                    else {
                        throw DemarkError.libraryLoadingFailed("html-to-md not available in JSContext")
                    }

                    self.jsContext = context
                    self.isInitialized = true
                    self.logger.info("JSCore runtime initialized with html-to-md")
                    continuation.resume()

                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Check if initialized (async-safe)
    private func isInitializedAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(returning: self?.isInitialized ?? false)
            }
        }
    }
}
