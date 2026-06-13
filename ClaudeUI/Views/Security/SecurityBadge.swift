import SwiftUI

/// Compact severity pill shown in lists and detail headers.
struct SecurityBadge: View {
    let severity: SecuritySeverity
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: severity.symbolName)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
            if !compact {
                Text(severity.label)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(severity.color)
        .padding(.horizontal, compact ? 5 : 7)
        .padding(.vertical, compact ? 2 : 3)
        .background(severity.color.opacity(0.12))
        .clipShape(Capsule())
        .help(severity.label)
    }
}

/// Full findings list used in detail panes.
struct SecurityReportView: View {
    let report: SecurityReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Security")
                    .font(.headline)
                SecurityBadge(severity: report.worstSeverity)
            }

            if report.findings.isEmpty {
                Label("No issues detected by local checks.", systemImage: "checkmark.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                ForEach(report.findings) { finding in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: finding.severity.symbolName)
                            .foregroundStyle(finding.severity.color)
                            .font(.system(size: 13))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(finding.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text(finding.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Text("Local heuristic checks only — they flag common risks but don't guarantee safety. Review the source before trusting.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
