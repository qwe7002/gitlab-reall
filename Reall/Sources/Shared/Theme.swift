import SwiftUI

/// Centralised colors so the GitHub-like look stays consistent.
enum Theme {
    static let gitlabOrange = Color.accentColor

    static func ciColor(_ status: CIStatus) -> Color {
        switch status {
        case .success: return .green
        case .failed: return .red
        case .running: return .blue
        case .pending, .preparing, .created, .scheduled, .waitingForResource: return .orange
        case .canceled, .skipped: return .secondary
        case .manual: return .purple
        case .unknown: return .gray
        }
    }

    static func issueColor(open: Bool) -> Color { open ? .green : .purple }

    static func mrColor(_ state: GitLabMergeRequest.DisplayState) -> Color {
        switch state {
        case .open: return .green
        case .draft: return .secondary
        case .merged: return .purple
        case .closed: return .red
        }
    }

    /// Deterministic color for a GitLab label string (labels lack hex over the simple API).
    static func labelColor(for name: String) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .red, .teal, .indigo, .mint, .cyan]
        let hash = abs(name.hashValue)
        return palette[hash % palette.count]
    }
}
