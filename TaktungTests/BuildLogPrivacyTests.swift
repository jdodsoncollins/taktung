import Testing
@testable import Taktung

struct BuildLogPrivacyTests {
    @Test func removesAssignmentsCredentialsAndURLs() {
        for text in ["DATABASE_URL=synthetic-secret", "API_KEY: 'synthetic-secret'", "\"MAIL_TOKEN\": \"synthetic-secret\"", "Bearer synthetic-secret", "postgres://user:synthetic-secret@db.example/test"] {
            #expect(!redactBuildLog(text).contains("synthetic-secret"))
        }
    }

    @Test func retainsUsefulCompileEvidenceAndVariableNames() {
        let text = "Type error: Property 'title' does not exist on type 'PageProps'. Missing environment variable DATABASE_URL."
        #expect(redactBuildLog(text) == text)
    }
}
