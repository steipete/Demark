//
// MarkdownRenderer.swift
// Demark
//
// Created by Peter Steinberger on 12/28/2025.
//

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
    var parser = MarkdownParser(lines: markdown.components(separatedBy: .newlines))
    return parser.parse()
}

private struct MarkdownParser {
    let lines: [String]
    var elements: [MarkdownElement] = []
    var currentParagraph: [String] = []
    var index = 0

    mutating func parse() -> [MarkdownElement] {
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            let handled = handleHeading(line)
                || handleCodeBlock(line)
                || handleBlockquote(line)
                || handleHorizontalRule(line)
                || handleUnorderedList(line)
                || handleOrderedList(line)
            if handled {
                index += 1
                continue
            }

            currentParagraph.append(line)
            index += 1
        }

        flushParagraph()
        return elements
    }

    private mutating func flushParagraph() {
        guard !currentParagraph.isEmpty else { return }
        let content = currentParagraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        if !content.isEmpty {
            elements.append(MarkdownElement(type: .paragraph, content: content))
        }
        currentParagraph.removeAll()
    }

    private mutating func handleHeading(_ line: String) -> Bool {
        guard line.hasPrefix("#") else { return false }
        flushParagraph()
        let level = line.prefix(while: { $0 == "#" }).count
        let content = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        elements.append(MarkdownElement(type: .heading(level), content: content))
        return true
    }

    private mutating func handleCodeBlock(_ line: String) -> Bool {
        guard line.hasPrefix("```") else { return false }
        flushParagraph()
        let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var codeLines: [String] = []
        index += 1
        while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            codeLines.append(lines[index])
            index += 1
        }
        let code = codeLines.joined(separator: "\n")
        elements.append(MarkdownElement(type: .codeBlock(language.isEmpty ? nil : language), content: code))
        return true
    }

    private mutating func handleBlockquote(_ line: String) -> Bool {
        guard line.hasPrefix(">") else { return false }
        flushParagraph()
        let content = String(line.dropFirst(1)).trimmingCharacters(in: .whitespaces)
        elements.append(MarkdownElement(type: .blockquote, content: content))
        return true
    }

    private mutating func handleHorizontalRule(_ line: String) -> Bool {
        guard line.hasPrefix("---") || line.hasPrefix("***") else { return false }
        flushParagraph()
        elements.append(MarkdownElement(type: .horizontalRule))
        return true
    }

    private mutating func handleUnorderedList(_ line: String) -> Bool {
        guard line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") else { return false }
        flushParagraph()
        var listItems: [String] = []
        while index < lines.count {
            let listLine = lines[index].trimmingCharacters(in: .whitespaces)
            if listLine.hasPrefix("- ") || listLine.hasPrefix("* ") || listLine.hasPrefix("+ ") {
                let item = String(listLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                listItems.append(item)
                index += 1
            } else {
                break
            }
        }
        elements.append(MarkdownElement(type: .list(false), items: listItems))
        index -= 1
        return true
    }

    private mutating func handleOrderedList(_ line: String) -> Bool {
        guard line.range(of: #"^\d+\. "#, options: .regularExpression) != nil else { return false }
        flushParagraph()
        var listItems: [String] = []
        while index < lines.count {
            let listLine = lines[index].trimmingCharacters(in: .whitespaces)
            if listLine.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                let item = listLine.replacingOccurrences(of: #"^\d+\. "#, with: "", options: .regularExpression)
                listItems.append(item)
                index += 1
            } else {
                break
            }
        }
        elements.append(MarkdownElement(type: .list(true), items: listItems))
        index -= 1
        return true
    }
}
