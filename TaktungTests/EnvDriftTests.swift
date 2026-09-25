import Testing
@testable import Taktung

struct EnvDriftTests {
    @Test func neverIncludesValuesAndFlagsMissingProduction() {
        let vars = [
            EnvVarMeta(id: "1", key: "API_URL", type: "plain", target: ["preview"]),
            EnvVarMeta(id: "2", key: "API_URL", type: "plain", target: ["production"]),
            EnvVarMeta(id: "3", key: "SECRET_NAME", type: "secret", target: ["preview"]),
        ]
        let report = analyzeEnvDrift(vars)
        #expect(report.productionKeys == ["API_URL"])
        #expect(report.previewKeys.contains("SECRET_NAME"))
        #expect(report.findings.contains { $0.kind == .missingInProduction && $0.key == "SECRET_NAME" })
        let blob = report.findings.map(\.detail).joined()
        #expect(!blob.contains("sk_"))
        #expect(!blob.contains("secret-value"))
    }
}
