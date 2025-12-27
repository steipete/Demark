# Demark Example App

A demonstration app showcasing the Demark HTML to Markdown converter with support for both iOS and macOS.

## Features

- **Dual Engine Support**: Switch between Turndown.js (full-featured) and html-to-md (fast) engines
- **Real-time Conversion**: Convert HTML to Markdown instantly
- **Platform Native**: Optimized UI for both iOS and macOS
- **Sample Content**: Pre-loaded HTML samples for testing
- **Markdown Preview**: View both source and rendered Markdown

## Running the App

### Using Xcode (Recommended)

1. Open the Swift Package in Xcode:
   ```bash
   cd Example
   open Package.swift
   ```

2. Select the appropriate scheme:
   - **DemarkExample**: For macOS
   - **DemarkExample**: For iOS (select an iOS Simulator)

3. Press ⌘+R to build and run

### Using Command Line

For macOS:
```bash
cd Example
swift run DemarkExample
```

Note: iOS apps cannot be run directly from the command line.

## Project Structure

```
Example/
├── Sources/
│   └── DemarkExample/
│       ├── DemarkExampleApp.swift    # App entry point
│       ├── ContentView.swift         # Main view with platform switching
│       ├── ContentView-iOS.swift     # iOS-specific layout
│       ├── ContentView-macOS.swift   # macOS-specific layout
│       ├── MarkdownRenderer.swift    # Markdown preview renderer
│       └── Assets.xcassets/          # App icons and colors
├── Package.swift                      # Swift Package definition
└── README.md                         # This file
```

## Customization

### Conversion Options

The app demonstrates all available conversion options:

- **Engine**: Turndown.js or html-to-md
- **Heading Style**: ATX (`#`) or Setext (underline) - Turndown only
- **List Markers**: `-`, `*`, or `+`
- **Code Blocks**: Fenced (```) or Indented - Turndown only

### Adding Sample HTML

Edit the `SampleHTML` enum in `ContentView.swift` to add more HTML samples:

```swift
case myNewSample

var html: String {
    switch self {
    case .myNewSample:
        return """
        <h1>My Sample</h1>
        <p>Sample content here</p>
        """
    }
}
```

## Platform Differences

### iOS
- Uses `NavigationStack` for navigation
- Touch-optimized controls
- Supports both iPhone and iPad

### macOS
- Uses `HSplitView` for side-by-side layout
- Native macOS controls and styling
- Keyboard shortcuts (⌘+Return to convert)

## Requirements

- iOS 16.0+ / macOS 14.0+
- Xcode 16.0+
- Swift 6.0+
