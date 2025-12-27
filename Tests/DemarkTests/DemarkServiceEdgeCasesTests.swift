import Testing
@testable import Demark

@MainActor
struct DemarkServiceEdgeCasesTests {
    @Test("Empty input throws emptyResult")
    func emptyInputThrows() async {
        let service = Demark()

        do {
            _ = try await service.convertToMarkdown("")
            #expect(Bool(false), "Expected DemarkError.emptyResult for empty input")
        } catch DemarkError.emptyResult {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Whitespace input throws emptyResult")
    func whitespaceInputThrows() async {
        let service = Demark()

        do {
            _ = try await service.convertToMarkdown("   \n\t  ")
            #expect(Bool(false), "Expected DemarkError.emptyResult for whitespace input")
        } catch DemarkError.emptyResult {
            #expect(Bool(true))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Malformed HTML preserves content")
    func malformedHTMLPreservesContent() async throws {
        let service = Demark()
        let html = "<p>Unclosed paragraph <strong>bold text"

        let markdown = try await service.convertToMarkdown(html)

        #expect(markdown.contains("Unclosed paragraph"))
        #expect(markdown.contains("bold text"))
    }

    @Test("Script and style content is removed (Turndown)")
    func scriptAndStyleRemoval() async throws {
        let service = Demark()
        let html = """
        <div>
            <p>Visible content</p>
            <script>alert('This should be removed');</script>
            <style>body { color: red; }</style>
            <p>More visible content</p>
        </div>
        """

        let markdown = try await service.convertToMarkdown(html, options: DemarkOptions(engine: .turndown))

        #expect(markdown.contains("Visible content"))
        #expect(markdown.contains("More visible content"))
        #expect(!markdown.contains("alert"))
        #expect(!markdown.contains("body { color: red; }"))
    }
}

