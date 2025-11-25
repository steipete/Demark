import SwiftUI

// MARK: - Cross-platform Color Extension

#if os(iOS)
    import UIKit

    extension Color {
        static var textBackgroundColor: Color {
            Color(UIColor.secondarySystemBackground)
        }
    }
#else
    import AppKit

    extension Color {
        static var textBackgroundColor: Color {
            Color(NSColor.textBackgroundColor)
        }
    }
#endif

struct MarkdownRenderer: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(parseMarkdown(markdown), id: \.id) { element in
                renderElement(element)
            }
        }
    }

    private func renderElement(_ element: MarkdownElement) -> some View {
        Group {
            switch element.type {
            case let .heading(level):
                renderHeading(element.content, level: level)
            case .paragraph:
                renderParagraph(element.content)
            case let .list(isOrdered):
                renderList(element.items, ordered: isOrdered)
            case let .codeBlock(language):
                renderCodeBlock(element.content, language: language)
            case .blockquote:
                renderBlockquote(element.content)
            case .horizontalRule:
                renderHorizontalRule()
            case .table:
                renderTable(element.tableData)
            }
        }
    }

    private func renderHeading(_ text: String, level: Int) -> some View {
        Text(parseInlineMarkdown(text))
            .font(headingFont(for: level))
            .fontWeight(.bold)
            .padding(.vertical, headingSpacing(for: level))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func renderParagraph(_ text: String) -> some View {
        Text(parseInlineMarkdown(text))
            .font(.body)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func renderList(_ items: [String], ordered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .font(.body)
                        .frame(width: 20, alignment: .leading)

                    Text(parseInlineMarkdown(item))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 16)
    }

    private func renderCodeBlock(_ code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))

                    Spacer()
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #endif
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func renderBlockquote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 4)

            Text(parseInlineMarkdown(text))
                .font(.body)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 16)
        .padding(.vertical, 8)
    }

    private func renderHorizontalRule() -> some View {
        Divider()
            .padding(.vertical, 16)
    }

    private func renderTable(_ tableData: TableData?) -> some View {
        Group {
            if let table = tableData {
                VStack(spacing: 0) {
                    // Header
                    if !table.headers.isEmpty {
                        renderTableHeader(table.headers)
                    }

                    // Rows
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        renderTableRow(row)
                    }
                }
                .cornerRadius(8)
            } else {
                Text("Invalid table data")
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func renderTableHeader(_ headers: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                Text(parseInlineMarkdown(header))
                    .font(.headline)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))

                if index < headers.count - 1 {
                    Divider()
                }
            }
        }
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func renderTableRow(_ row: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                Text(parseInlineMarkdown(cell))
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if index < row.count - 1 {
                    Divider()
                }
            }
        }
        .background(Color.textBackgroundColor)
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Inline Markdown Parsing (Simplified)

    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        // For the example app, we'll use a simplified approach
        // In a production app, you might want to use a proper markdown parser

        var result = text

        // Remove markdown syntax for basic rendering
        // Bold (**text** or __text__)
        result = result.replacingOccurrences(of: #"\*\*(.*?)\*\*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"__(.*?)__"#, with: "$1", options: .regularExpression)

        // Italic (*text* or _text_)
        result = result.replacingOccurrences(of: #"\*(.*?)\*"#, with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: #"_(.*?)_"#, with: "$1", options: .regularExpression)

        // Inline code (`code`)
        result = result.replacingOccurrences(of: #"`(.*?)`"#, with: "$1", options: .regularExpression)

        // Links [text](url)
        result = result.replacingOccurrences(of: #"\[(.*?)\]\(.*?\)"#, with: "$1", options: .regularExpression)

        return AttributedString(result)
    }

    // MARK: - Utility Functions

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: .largeTitle
        case 2: .title
        case 3: .title2
        case 4: .title3
        case 5: .headline
        default: .subheadline
        }
    }

    private func headingSpacing(for level: Int) -> CGFloat {
        switch level {
        case 1: 20
        case 2: 16
        case 3: 12
        case 4: 10
        case 5: 8
        default: 6
        }
    }
}

// MARK: - Markdown Parsing

struct MarkdownElement {
    let id = UUID()
    let type: ElementType
    let content: String
    let items: [String]
    let tableData: TableData?

    enum ElementType {
        case heading(Int)
        case paragraph
        case list(Bool) // true for ordered, false for unordered
        case codeBlock(String?) // language
        case blockquote
        case horizontalRule
        case table
    }

    init(type: ElementType, content: String = "", items: [String] = [], tableData: TableData? = nil) {
        self.type = type
        self.content = content
        self.items = items
        self.tableData = tableData
    }
}

struct TableData {
    let headers: [String]
    let rows: [[String]]
}

// Simple markdown parser for demonstration
func parseMarkdown(_ markdown: String) -> [MarkdownElement] {
    let lines = markdown.components(separatedBy: .newlines)
    var elements: [MarkdownElement] = []
    var currentParagraph: [String] = []
    var i = 0

    func flushParagraph() {
        if !currentParagraph.isEmpty {
            let content = currentParagraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !content.isEmpty {
                elements.append(MarkdownElement(type: .paragraph, content: content))
            }
            currentParagraph.removeAll()
        }
    }

    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)

        if line.isEmpty {
            flushParagraph()
            i += 1
            continue
        }

        // Headings
        if line.hasPrefix("#") {
            flushParagraph()
            let level = line.prefix(while: { $0 == "#" }).count
            let content = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            elements.append(MarkdownElement(type: .heading(level), content: content))
        }
        // Code blocks
        else if line.hasPrefix("```") {
            flushParagraph()
            let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var codeLines: [String] = []
            i += 1

            while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }

            let code = codeLines.joined(separator: "\n")
            elements.append(MarkdownElement(type: .codeBlock(language.isEmpty ? nil : language), content: code))
        }
        // Blockquotes
        else if line.hasPrefix(">") {
            flushParagraph()
            let content = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
            elements.append(MarkdownElement(type: .blockquote, content: content))
        }
        // Horizontal rules
        else if line.hasPrefix("---") || line.hasPrefix("***") {
            flushParagraph()
            elements.append(MarkdownElement(type: .horizontalRule))
        }
        // Lists
        else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            flushParagraph()
            var listItems: [String] = []

            while i < lines.count {
                let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                if listLine.hasPrefix("- ") || listLine.hasPrefix("* ") || listLine.hasPrefix("+ ") {
                    let item = String(listLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    listItems.append(item)
                    i += 1
                } else if listLine.isEmpty {
                    break
                } else {
                    break
                }
            }

            elements.append(MarkdownElement(type: .list(false), items: listItems))
            i -= 1 // Adjust since the loop will increment
        }
        // Ordered lists
        else if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
            flushParagraph()
            var listItems: [String] = []

            while i < lines.count {
                let listLine = lines[i].trimmingCharacters(in: .whitespaces)
                if listLine.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                    let item = listLine.replacingOccurrences(of: #"^\d+\. "#, with: "", options: .regularExpression)
                    listItems.append(item)
                    i += 1
                } else if listLine.isEmpty {
                    break
                } else {
                    break
                }
            }

            elements.append(MarkdownElement(type: .list(true), items: listItems))
            i -= 1 // Adjust since the loop will increment
        }
        // Regular paragraph
        else {
            currentParagraph.append(line)
        }

        i += 1
    }

    flushParagraph()
    return elements
}
