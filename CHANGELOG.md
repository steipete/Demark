# Changelog

## [1.0.1] - 2025-12-27

### Changed
- Minimum iOS deployment target is now iOS 16.
- Updated Turndown.js to 7.2.2.
- Unordered list markers are normalized to match `bulletListMarker` for both engines.

## [1.0.1] - Unreleased

### Changed
- **iOS Deployment Target**: Lowered minimum iOS version to 16.0 across package and example app
- **Example App**: Updated iOS deployment target and SwiftUI change handlers for iOS 16 compatibility
- **Docs**: Updated platform requirements to reflect iOS 16 support

## [1.0.0] - 2024-05-30

### 🎉 Initial Release

The first stable release of **Demark** - a modern Swift package for converting HTML to Markdown using Turndown.js in a WKWebView environment.

### Added

#### Core Library
- **Cross-Platform Support**: Full compatibility with iOS 16.0+, macOS 14.0+, watchOS 10.0+, tvOS 17.0+, and visionOS 1.0+
- **Swift 6 Ready**: Complete Swift 6 support with strict concurrency checking enabled
- **WKWebView Integration**: Real browser DOM environment for accurate HTML parsing using WebKit framework
- **Turndown.js Powered**: Industry-standard HTML to Markdown conversion engine (v7.1.1)
- **Zero Dependencies**: Only requires WebKit framework - no external dependencies
- **Async/Await Support**: Modern Swift concurrency with `@MainActor` isolation

#### Conversion Features
- **Comprehensive HTML Support**: All standard HTML elements including headings, lists, links, images, code blocks, tables, and more
- **Configurable Output**: Extensive customization options through `DemarkOptions`
  - Heading styles: ATX (`#`) or Setext (underline)
  - List markers: `-`, `*`, or `+` for bullet points
  - Code block styles: Fenced (```) or indented
- **CommonMark Compliant**: Standard Markdown output that works everywhere
- **Error Handling**: Comprehensive error types with detailed messages and recovery suggestions
- **Performance Optimized**: ~100ms first conversion, ~10-50ms subsequent conversions

#### API Design
- **Simple API**: Single `Demark` class with `convertToMarkdown` methods
- **Options Support**: Optional `DemarkOptions` parameter for customization
- **Thread Safety**: Main actor requirement clearly documented and enforced
- **Resource Management**: Automatic JavaScript library bundling and loading

#### Testing
- **Modern swift-testing Framework**: Uses swift-testing (included in Xcode 16.3+) instead of legacy XCTest
- **Comprehensive Test Suite**: 900+ lines of tests covering:
  - Basic HTML conversion (headings, paragraphs, emphasis, links, lists, code blocks)
  - Complex HTML structures and nested elements
  - Custom options testing (heading styles, bullet markers, code block styles)
  - Edge cases and error handling (empty HTML, malformed HTML, special characters)
  - Performance tests with concurrent conversions and large documents
  - Empty result error handling with detailed test cases
- **Integration Tests**: JavaScript library loading, WKWebView setup, and basic conversion verification
- **Cross-Platform Testing**: Tests work across all supported Apple platforms

#### Example Application
- **Dual-Pane Interface**: HTML input on left, Markdown output on right
- **Live Preview**: Real-time conversion with Source and Rendered tabs
- **Sample Documents**: Pre-built HTML examples (Simple, Blog, Documentation, Complex)
- **Configuration Panel**: Interactive options adjustment
- **SwiftUI Architecture**: Modern UI with Swift 6 concurrency
- **Cross-Platform**: Works on both macOS and iOS

#### Documentation
- **Comprehensive README**: Complete usage guide with examples
- **API Documentation**: Detailed documentation for all public APIs
- **Example Code**: Multiple usage scenarios and platform-specific examples
- **Performance Guidelines**: Thread safety and performance characteristics
- **Migration Guide**: Clear requirements and installation instructions

#### Developer Experience
- **Swift Package Manager**: Easy integration with SPM
- **Xcode Integration**: Generate Xcode projects for development
- **Build Scripts**: Convenience scripts for building and running
- **CI Ready**: All tests pass and build successfully

### Technical Details

#### Supported HTML Elements
- **Headings**: `<h1>` through `<h6>` with configurable styles
- **Text Formatting**: `<strong>`, `<em>`, `<code>`, `<del>`, `<ins>`, `<sup>`, `<sub>`
- **Lists**: `<ul>`, `<ol>`, `<li>` with proper nesting and configurable markers
- **Links and Media**: `<a>`, `<img>` with full attribute preservation
- **Code**: `<pre>`, `<code>` with language detection and configurable styles
- **Tables**: `<table>`, `<tr>`, `<td>`, `<th>` (GitHub Flavored Markdown)
- **Block Elements**: `<div>`, `<p>`, `<blockquote>`, `<hr>`
- **Semantic Elements**: `<article>`, `<section>`, `<header>`, `<footer>`

#### Error Types
- `turndownLibraryNotFound`: JavaScript library missing from bundle
- `conversionFailed`: HTML conversion process failed
- `invalidInput`: Invalid HTML input with details
- `webViewInitializationFailed`: WKWebView couldn't be created
- `emptyResult`: Conversion produced empty result
- `jsException`: JavaScript execution error

#### Performance Characteristics
- **Memory Efficient**: Single WKWebView instance per Demark object
- **Platform Optimized**: Different configurations for each platform
- **Lazy Loading**: JavaScript libraries loaded on first use
- **Resource Cleanup**: Automatic resource management

### Platform Support

#### macOS (14.0+)
- Full functionality with desktop optimizations
- Enhanced JavaScript execution environment
- Optimized for large document processing

#### iOS (17.0+) & visionOS (1.0+)
- Full functionality with mobile/spatial optimizations
- Respects system memory constraints
- Optimized for touch/gesture interfaces

#### watchOS (10.0+) & tvOS (17.0+)
- Core functionality with minimal WebView footprint
- Optimized for limited resources
- Essential conversion features available

### Breaking Changes
- N/A (initial release)

### Known Issues
- WKWebView requires main thread execution (by design)
- Some concurrent operations may fail in test environments
- JavaScript exceptions may occur with deeply malformed HTML

### Contributors
- **Peter Steinberger** ([@steipete](https://github.com/steipete)) - Initial implementation and architecture

### Acknowledgments
- **Turndown.js**: The powerful HTML to Markdown conversion engine by [Dom Christie](https://github.com/mixmark-io/turndown)
- **Swift Community**: For the amazing Swift language and ecosystem
- **WebKit Team**: For providing the robust WKWebView framework

---

**Full Changelog**: https://github.com/steipete/Demark/commits/1.0.0
