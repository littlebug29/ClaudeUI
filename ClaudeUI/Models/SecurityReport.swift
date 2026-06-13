import SwiftUI

/// Severity of a security finding, ordered so the highest can be derived.
enum SecuritySeverity: Int, Comparable, CaseIterable {
    case clean = 0
    case info = 1
    case warning = 2
    case critical = 3

    static func < (lhs: SecuritySeverity, rhs: SecuritySeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .clean: return "No issues"
        case .info: return "Notice"
        case .warning: return "Caution"
        case .critical: return "High risk"
        }
    }

    var symbolName: String {
        switch self {
        case .clean: return "checkmark.shield.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .clean: return .green
        case .info: return .secondary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct SecurityFinding: Identifiable, Hashable {
    let id = UUID()
    let severity: SecuritySeverity
    let title: String
    let detail: String
}

struct SecurityReport: Hashable {
    let findings: [SecurityFinding]

    var worstSeverity: SecuritySeverity {
        findings.map(\.severity).max() ?? .clean
    }

    static let clean = SecurityReport(findings: [])
}
