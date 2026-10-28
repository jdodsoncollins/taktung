import Foundation
import Testing
@testable import Taktung

struct BuildFailurePolicyTests {
    private func lines(_ texts: [String], stderr: Set<Int> = []) -> [BuildLogLine] {
        texts.enumerated().map { BuildLogLine(text: $0.element, type: stderr.contains($0.offset) ? "stderr" : "stdout", created: nil) }
    }

    @Test func excerptKeepsContextAroundTheFirstAndLastErrors() {
        var texts = (0..<60).map { "step \($0) ok" }
        texts[20] = "Type error: Property 'title' does not exist on type 'PageProps'."
        texts[50] = "Error: Command \"npm run build\" exited with 1"
        let excerpt = BuildFailurePolicy.excerpt(from: lines(texts))
        let kept = excerpt?.lines ?? []
        #expect(kept.contains(texts[20]))
        #expect(kept.contains(texts[50]))
        #expect(kept.contains("step 18 ok") && kept.contains("step 22 ok"))
        #expect(kept.contains("step 48 ok") && kept.contains("step 52 ok"))
        #expect(!kept.contains("step 5 ok"))
        #expect(kept == kept.sorted { texts.firstIndex(of: $0)! < texts.firstIndex(of: $1)! })
    }

    @Test func excerptRedactsCredentialsAndStaysBounded() {
        let secret = lines(["Error: request failed with API_KEY=abc123secretvalue",
                            "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.abc",
                            "fatal: could not read from https://user:hunter2@example.com/repo.git"], stderr: [0, 1, 2])
        let excerpt = BuildFailurePolicy.excerpt(from: secret)
        let text = excerpt?.text ?? ""
        #expect(!text.contains("abc123secretvalue"))
        #expect(!text.contains("eyJ"))
        #expect(!text.contains("hunter2"))
        #expect(text.contains("[REDACTED]"))

        let flood = lines((0..<500).map { "error \($0): " + String(repeating: "x", count: 400) })
        let bounded = BuildFailurePolicy.excerpt(from: flood)
        #expect((bounded?.lines.count ?? 0) <= BuildFailurePolicy.maximumLines)
        #expect((bounded?.text.utf8.count ?? .max) <= BuildFailurePolicy.maximumBytes)
        #expect(bounded?.lines.allSatisfy { $0.count <= BuildFailurePolicy.maximumLineCharacters } == true)
        #expect(bounded.flatMap(BuildFailurePolicy.prompt) != nil)
    }

    @Test func quietLogsFallBackToTheTailAndEmptyLogsGiveNothing() {
        let quiet = BuildFailurePolicy.excerpt(from: lines((0..<20).map { "step \($0)" }))
        #expect(quiet?.lines == (12..<20).map { "step \($0)" })
        #expect(BuildFailurePolicy.excerpt(from: []) == nil)
        #expect(BuildFailurePolicy.excerpt(from: lines(["   ", ""])) == nil)
        // Secret-like material that survives redaction keeps the whole excerpt away from the model and the screen.
        #expect(BuildFailurePolicy.excerpt(from: lines(["-----BEGIN PRIVATE KEY----- failed"])) == nil)
    }

    @Test func explanationsMustStayGroundedInTheExcerpt() {
        let excerpt = BuildFailureExcerpt(lines: [
            "Type error: Property 'title' does not exist on type 'PageProps'.",
            "Error: Command \"npm run build\" exited with 1",
        ])
        let grounded = "The build failed on a type error: 'title' does not exist on type 'PageProps', so npm run build exited with 1."
        #expect(BuildFailurePolicy.accept(grounded, excerpt: excerpt) == grounded)
        #expect(BuildFailurePolicy.accept("The build didn't compile because a property was missing.", excerpt: excerpt) != nil)
        // Invented files, packages or codes are rejected.
        #expect(BuildFailurePolicy.accept("The import in src/pages/index.tsx failed.", excerpt: excerpt) == nil)
        #expect(BuildFailurePolicy.accept("The build failed with `ERR_MODULE_NOT_FOUND`.", excerpt: excerpt) == nil)
        #expect(BuildFailurePolicy.accept("The 'next.config.js' file is invalid.", excerpt: excerpt) == nil)
        // Format, privacy and action limits.
        #expect(BuildFailurePolicy.accept("Fix the type and redeploy.", excerpt: excerpt) == nil)
        #expect(BuildFailurePolicy.accept("A type error.\nSecond line.", excerpt: excerpt) == nil)
        #expect(BuildFailurePolicy.accept("A type error stopped the build", excerpt: excerpt) == nil)
        #expect(BuildFailurePolicy.accept(String(repeating: "word ", count: 50) + "end.", excerpt: excerpt) == nil)
        #expect(BuildFailurePolicy.accept("It failed because API_KEY=abc123 was wrong.", excerpt: excerpt) == nil)
    }
}
