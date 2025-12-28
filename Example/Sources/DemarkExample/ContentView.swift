//
// ContentView.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

import Demark
import SwiftUI
#if os(iOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

struct ContentView: View {
    @State var htmlInput: String = SampleHTML.defaultHTML
    @State var markdownOutput: String = ""
    @State var isConverting: Bool = false
    @State var conversionError: String?
    @State var selectedTab: OutputTab = .source
    @State var options = DemarkOptions()
    @State var selectedEngine: ConversionEngine = .turndown

    private let demark = Demark()

    enum OutputTab: String, CaseIterable {
        case source = "Source"
        case rendered = "Rendered"

        var icon: String {
            switch self {
            case .source: "doc.text"
            case .rendered: "eye"
            }
        }
    }

    var body: some View {
        #if os(macOS)
            macOSLayout
        #else
            iOSLayout
        #endif
    }

    // MARK: - Input Section

    var inputHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("HTML Input", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                sampleHTMLMenu
            }

            Text("Paste or type your HTML content below")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    var inputEditor: some View {
        ScrollView {
            TextEditor(text: $htmlInput)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .background(platformBackgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    var sampleHTMLMenu: some View {
        Menu("Sample HTML") {
            ForEach(SampleHTML.allCases, id: \.self) { sample in
                Button(sample.name) {
                    htmlInput = sample.html
                }
            }
        }
        .menuStyle(.borderlessButton)
        .font(.caption)
    }

    // MARK: - Options Panel

    var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversion Options")
                .font(.headline)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Text("Engine:")
                        .frame(width: 110, alignment: .trailing)
                        .foregroundColor(.secondary)

                    Picker("", selection: $selectedEngine) {
                        Text("Turndown (Full Featured)").tag(ConversionEngine.turndown)
                        Text("html-to-md (Fast)").tag(ConversionEngine.htmlToMd)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    .onChange(of: selectedEngine) { newValue in
                        options.engine = newValue
                    }

                    Spacer()
                }

                HStack(spacing: 16) {
                    Text("Heading Style:")
                        .frame(width: 110, alignment: .trailing)
                        .foregroundColor(.secondary)

                    Picker("", selection: $options.headingStyle) {
                        Text("ATX (# Heading)").tag(DemarkHeadingStyle.atx)
                        Text("Setext (Underline)").tag(DemarkHeadingStyle.setext)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    .disabled(selectedEngine == .htmlToMd)
                    .opacity(selectedEngine == .htmlToMd ? 0.5 : 1.0)

                    Spacer()
                }

                HStack(spacing: 16) {
                    Text("List Marker:")
                        .frame(width: 110, alignment: .trailing)
                        .foregroundColor(.secondary)

                    Picker("", selection: $options.bulletListMarker) {
                        Text("- (Dash)").tag("-")
                        Text("* (Star)").tag("*")
                        Text("+ (Plus)").tag("+")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)

                    Spacer()
                }

                HStack(spacing: 16) {
                    Text("Code Blocks:")
                        .frame(width: 110, alignment: .trailing)
                        .foregroundColor(.secondary)

                    Picker("", selection: $options.codeBlockStyle) {
                        Text("Fenced (```)").tag(DemarkCodeBlockStyle.fenced)
                        Text("Indented").tag(DemarkCodeBlockStyle.indented)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                    .disabled(selectedEngine == .htmlToMd)
                    .opacity(selectedEngine == .htmlToMd ? 0.5 : 1.0)

                    Spacer()
                }
            }
            .font(.caption)

            if selectedEngine == .htmlToMd {
                Text("Note: html-to-md only supports ATX headings and fenced code blocks")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(platformControlBackgroundColor)
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Output Section

    var outputHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Markdown Output", systemImage: "doc.text")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if isConverting {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                copyButton
            }

            if let error = conversionError {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else if !markdownOutput.isEmpty {
                Text("\(markdownOutput.count) characters converted")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Click 'Convert' to generate Markdown")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    var outputTabs: some View {
        HStack(spacing: 0) {
            ForEach(OutputTab.allCases, id: \.self) { tab in
                Button(
                    action: { selectedTab = tab },
                    label: {
                        HStack {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor : Color.clear)
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .cornerRadius(6)
                    }
                )
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    var outputContent: some View {
        Group {
            switch selectedTab {
            case .source:
                markdownSourceView
            case .rendered:
                markdownRenderedView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var markdownSourceView: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(markdownOutput.isEmpty ? "No content yet" : markdownOutput)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(markdownOutput.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
        }
        .background(platformBackgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var markdownRenderedView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if markdownOutput.isEmpty {
                    Text("No content to render")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    MarkdownRenderer(markdown: markdownOutput)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
        }
        .background(platformBackgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom)
    }

    // MARK: - Action Buttons

    var convertButton: some View {
        Button(action: convertHTML) {
            HStack {
                Image(systemName: "arrow.right.circle.fill")
                Text("Convert")
            }
        }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(isConverting || htmlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var copyButton: some View {
        Button(action: copyMarkdown) {
            Image(systemName: "doc.on.doc")
        }
        .disabled(markdownOutput.isEmpty)
        .help("Copy Markdown to Clipboard")
    }

    // MARK: - Actions

    @MainActor
    func convertHTML() {
        guard !htmlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isConverting = true
        conversionError = nil

        Task {
            do {
                let result = try await demark.convertToMarkdown(htmlInput, options: options)
                markdownOutput = result
                conversionError = nil
            } catch {
                conversionError = error.localizedDescription
                markdownOutput = ""
            }

            isConverting = false
        }
    }

    func copyMarkdown() {
        #if os(macOS)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(markdownOutput, forType: .string)
        #elseif os(iOS)
            UIPasteboard.general.string = markdownOutput
        #endif
    }

    // MARK: - Platform Helpers

    private var platformBackgroundColor: Color {
        #if os(macOS)
            return Color(NSColor.textBackgroundColor)
        #else
            return Color(.systemBackground)
        #endif
    }

    private var platformControlBackgroundColor: Color {
        #if os(macOS)
            return Color(NSColor.controlBackgroundColor)
        #else
            return Color(.secondarySystemBackground)
        #endif
    }
}

// MARK: - Sample HTML Data

enum SampleHTML: CaseIterable {
    case simple
    case blog
    case documentation
    case complex

    var name: String {
        switch self {
        case .simple: "Simple HTML"
        case .blog: "Blog Post"
        case .documentation: "Documentation"
        case .complex: "Complex Document"
        }
    }

    var html: String {
        switch self {
        case .simple:
            """
            <h1>Hello World</h1>
            <p>This is a <strong>simple</strong> HTML document with some <em>formatting</em>.</p>
            <ul>
                <li>First item</li>
                <li>Second item</li>
                <li>Third item</li>
            </ul>
            """

        case .blog:
            """
            <article>
                <h1>My Awesome Blog Post</h1>
                <p>
                    Welcome to my <strong>amazing</strong> blog! Today I want to share some insights about
                    <em>web development</em>.
                </p>

                <h2>Key Points</h2>
                <ul>
                    <li>HTML is the backbone of the web</li>
                    <li>Markdown is great for writing</li>
                    <li>Conversion tools are <a href="https://example.com">super useful</a></li>
                </ul>

                <blockquote>
                    <p>"The best way to learn is by doing." - Someone wise</p>
                </blockquote>

                <h3>Code Example</h3>
                <pre><code class="javascript">
            function greet(name) {
                console.log(`Hello, ${name}!`);
            }
                </code></pre>
            </article>
            """

        case .documentation:
            """
            <div class="documentation">
                <h1>API Documentation</h1>
                <p>This is the documentation for our <code>amazing-library</code>.</p>

                <h2>Installation</h2>
                <p>Install the library using your favorite package manager:</p>
                <pre><code class="bash">npm install amazing-library</code></pre>

                <h2>Usage</h2>
                <p>Here's how to use the library:</p>

                <ol>
                    <li>Import the library</li>
                    <li>Initialize the component</li>
                    <li>Configure your options</li>
                    <li>Call the main function</li>
                </ol>

                <h3>Example</h3>
                <pre><code class="javascript">
            import { AmazingComponent } from 'amazing-library';

            const component = new AmazingComponent({
                option1: 'value1',
                option2: true
            });

            component.run();
                </code></pre>

                <h2>API Reference</h2>
                <table>
                    <tr>
                        <th>Method</th>
                        <th>Description</th>
                        <th>Parameters</th>
                    </tr>
                    <tr>
                        <td><code>run()</code></td>
                        <td>Starts the component</td>
                        <td>None</td>
                    </tr>
                    <tr>
                        <td><code>stop()</code></td>
                        <td>Stops the component</td>
                        <td>None</td>
                    </tr>
                </table>
            </div>
            """

        case .complex:
            """
            <html>
            <head>
                <title>Complex Document</title>
            </head>
            <body>
                <header>
                    <h1>Complex HTML Document</h1>
                    <nav>
                        <ul>
                            <li><a href="#section1">Section 1</a></li>
                            <li><a href="#section2">Section 2</a></li>
                            <li><a href="#section3">Section 3</a></li>
                        </ul>
                    </nav>
                </header>

                <main>
                    <section id="section1">
                        <h2>Introduction</h2>
                        <p>
                            This document contains <strong>various HTML elements</strong> to test the conversion
                            capabilities.
                        </p>

                        <div class="highlight">
                            <p>
                                This is a highlighted section with <em>emphasized text</em> and
                                <code>inline code</code>.
                            </p>
                        </div>
                    </section>

                    <section id="section2">
                        <h2>Lists and Links</h2>
                        <p>Here are some different list types:</p>

                        <h3>Unordered List</h3>
                        <ul>
                            <li>Item one</li>
                            <li>Item two with <a href="https://example.com" title="Example">external link</a></li>
                            <li>Item three
                                <ul>
                                    <li>Nested item</li>
                                    <li>Another nested item</li>
                                </ul>
                            </li>
                        </ul>

                        <h3>Ordered List</h3>
                        <ol>
                            <li>First step</li>
                            <li>Second step</li>
                            <li>Final step</li>
                        </ol>
                    </section>

                    <section id="section3">
                        <h2>Code and Quotes</h2>
                        <blockquote>
                            <p>This is a blockquote with <strong>bold text</strong> inside.</p>
                            <cite>— Famous Person</cite>
                        </blockquote>

                        <h3>Code Block</h3>
                        <pre><code class="python">
            def hello_world():
                print("Hello, World!")
                return True

            if __name__ == "__main__":
                hello_world()
                        </code></pre>

                        <p>And here's some <code>inline code</code> in a paragraph.</p>
                    </section>
                </main>

                <footer>
                    <hr>
                    <p><small>© 2024 Example Company. All rights reserved.</small></p>
                </footer>
            </body>
            </html>
            """
        }
    }

    static let defaultHTML = SampleHTML.simple.html
}
