import Testing
@testable import Demark

@MainActor
struct DemarkServiceConcurrencyTests {
    @Test("Concurrent conversions are consistent")
    func concurrentConversions() async throws {
        let service = Demark()
        let html = "<h1>Test</h1><p>This is a <strong>test</strong> paragraph.</p>"
        let options = DemarkOptions(engine: .htmlToMd, bulletListMarker: "-")

        let tasks = (1 ... 6).map { _ in
            Task { try await service.convertToMarkdown(html, options: options) }
        }

        let results = try await withThrowingTaskGroup(of: String.self) { group in
            for task in tasks {
                group.addTask { try await task.value }
            }

            var results: [String] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        #expect(results.count == 6)
        for result in results {
            #expect(result.contains("# Test") || result.contains("Test"))
            #expect(result.contains("**test**"))
        }
    }
}
