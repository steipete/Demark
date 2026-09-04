# Using Demark

Demark has one main-actor-isolated entry point with overloads for HTML strings and URLs. This guide covers the decisions and options beyond the README quick start.

## Execution model

`Demark` is annotated with `@MainActor`, so create and call it from a main-actor context. The default Turndown engine keeps a reusable `WKWebView` on that actor. The `html-to-md` engine performs its JavaScriptCore work on a dedicated serial queue, but callers still enter through the main-actor-isolated public API.

When `.turndown` fails, Demark retries the same conversion with `.htmlToMd`. Selecting `.htmlToMd` directly does not fall back to Turndown.

Both JavaScript libraries are bundled as package resources. Demark has no external Swift Package dependencies and does not download conversion code at runtime.

## Conversion options

`DemarkOptions()` selects Turndown, ATX headings, `-` bullets, and fenced code blocks.

| Option | Default | Behavior |
|---|---|---|
| `engine` | `.turndown` | Chooses `.turndown` or `.htmlToMd` |
| `headingStyle` | `.atx` | ATX or Setext headings; Turndown only |
| `bulletListMarker` | `"-"` | Normalizes unordered lists to `-`, `*`, or `+` |
| `codeBlockStyle` | `.fenced` | Fenced or indented blocks; Turndown only |
| `skipTags` | `[]` | Preserves matching tags/content in Turndown; unwraps matching tags in `html-to-md` |
| `ignoreTags` | `[]` | Removes matching tags and their content |
| `emptyTags` | `[]` | Processes matching tags with `html-to-md`'s empty-tag behavior; ignored by Turndown |

```swift
import Demark

@MainActor
func convertDocument(_ html: String) async throws -> String {
    let options = DemarkOptions(
        engine: .turndown,
        headingStyle: .setext,
        bulletListMarker: "*",
        codeBlockStyle: .fenced,
        ignoreTags: ["script", "style"]
    )
    return try await Demark().convertToMarkdown(html, options: options)
}
```

Turndown removes `script` and `style` by default and preserves `del`, `ins`, `sup`, and `sub` as HTML. The two engines do not promise byte-for-byte identical Markdown; compare them with representative input before changing engines.

Bullet-marker normalization preserves fenced code content, including examples containing shorter fences or a different fence character. Lists after the closing fence still use the requested marker.

## Web pages

The URL overload accepts only HTTP and HTTPS URLs. It creates an ephemeral `WKWebView`, waits for navigation, optionally waits for `document.readyState == "complete"`, applies the idle delay, and extracts the document HTML. A CSS selector can limit extraction to one element.

| URL loading option | Default | Behavior |
|---|---:|---|
| `timeout` | 30 seconds | Maximum navigation time |
| `waitForIdle` | `true` | Polls the document ready state after navigation |
| `idleDelay` | 0.5 seconds | Additional delay before extraction |
| `contentSelector` | `nil` | Extracts the first matching element instead of the full document |
| `userAgent` | `nil` | Overrides the web view user agent |

```swift
import Demark
import Foundation

@MainActor
func convertArticle(at url: URL) async throws -> String {
    let loading = URLLoadingOptions(
        timeout: 20,
        contentSelector: "main article"
    )
    return try await Demark().convertToMarkdown(
        url: url,
        loadingOptions: loading
    )
}
```

A selector with no match throws `.contentSelectorNotFound`. Plain HTTP may require an App Transport Security exception in the host app.

## Errors

All package-defined failures use `DemarkError`, which conforms to `LocalizedError`:

```swift
import Demark
import Foundation

@MainActor
func convertOrDescribe(_ html: String) async -> String {
    do {
        return try await Demark().convertToMarkdown(html)
    } catch let error as DemarkError {
        return error.localizedDescription
    } catch {
        return error.localizedDescription
    }
}
```

The cases fall into four groups:

| Area | Cases |
|---|---|
| Input/output | `emptyResult`, `invalidInput`, `conversionFailed` |
| JavaScript and resources | `jsEnvironmentInitializationFailed`, `jsContextCreationFailed`, `jsException`, `libraryNotFound`, `libraryLoadingFailed`, `bundleResourceMissing`, `turndownServiceCreationFailed` |
| WebKit and URL loading | `webViewInitializationFailed`, `urlLoadingTimeout`, `urlNavigationFailed`, `invalidURLScheme`, `contentSelectorNotFound` |
| Platform | `runtimeUnavailable` |

Empty or whitespace-only input throws `.emptyResult`. Platforms without a required Apple framework throw `.runtimeUnavailable` for the affected engine or URL API.

## What gets converted

The test suite covers headings, paragraphs, emphasis, links, images, ordered and unordered lists, nested content, blockquotes, horizontal rules, inline code, and code blocks. Conversion details still depend on the selected JavaScript engine and its bundled version.

For an interactive comparison, run the [example app](../Example/README.md). It exposes engine selection, heading style, bullet marker, and code-block style alongside Markdown source and rendered output.
