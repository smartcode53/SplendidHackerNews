import Foundation

#if DEBUG

enum HNDiagnosticsErrorCode: String {
    case loginMarkerNotFound = "LoginMarkerNotFound"
    case voteLinkNotFound = "VoteLinkNotFound"
    case alreadyVotedNotDetected = "AlreadyVotedNotDetected"
    case replyFormNotFound = "ReplyFormNotFound"
    case commentIdNotFound = "CommentIdNotFound"
    case requestFailed = "RequestFailed"
    case parseFailed = "ParseFailed"
}

struct HNDiagnosticsCheck: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let errorCode: HNDiagnosticsErrorCode?
    let url: String
    let statusCode: Int?
    let selectors: [String]
    let excerpt: String?
    let message: String?
}

struct HNDiagnosticsReport {
    let generatedAt: Date
    let checks: [HNDiagnosticsCheck]

    var hasFailures: Bool {
        checks.contains { !$0.passed }
    }

    func formatted() -> String {
        var lines: [String] = []
        lines.append("HN Diagnostics Report")
        lines.append("Generated: \(generatedAt.formatted(date: .abbreviated, time: .standard))")
        lines.append("")
        for check in checks {
            lines.append("• \(check.name): \(check.passed ? "PASS" : "FAIL")")
            if !check.passed {
                if let errorCode = check.errorCode {
                    lines.append("  Error: \(errorCode.rawValue)")
                }
                lines.append("  URL: \(check.url)")
                if let status = check.statusCode {
                    lines.append("  Status: \(status)")
                }
                if !check.selectors.isEmpty {
                    lines.append("  Selectors: \(check.selectors.joined(separator: ", "))")
                }
                if let message = check.message {
                    lines.append("  Message: \(message)")
                }
                if let excerpt = check.excerpt {
                    lines.append("  Excerpt:")
                    lines.append(excerpt)
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

#endif
