import SwiftUI

/// Shows a job's raw trace/log in a monospaced, terminal-style view.
struct JobLogView: View {
    @Environment(AppSession.self) private var session
    let projectId: Int
    let job: GitLabJob

    @State private var log: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isLoading {
                    ProgressView().padding(.top, 40)
                } else if let errorMessage {
                    MessageStateView(systemImage: "doc.text.magnifyingglass",
                                     title: "No log available",
                                     message: errorMessage)
                } else {
                    Text(cleanedLog.isEmpty ? "No output." : cleanedLog)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .id("logBottom")
                }
            }
            .background(Color(.systemBackground))
            .onChange(of: log) {
                withAnimation { proxy.scrollTo("logBottom", anchor: .bottom) }
            }
        }
        .navigationTitle(job.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                StatusBadge(CIStatus(job.status).label, color: Theme.ciColor(CIStatus(job.status)))
                if let url = job.webURL {
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    /// Strip ANSI color escape codes that GitLab runners emit.
    private var cleanedLog: String {
        log.replacingOccurrences(of: "\u{1B}\\[[0-9;]*[A-Za-z]",
                                 with: "",
                                 options: .regularExpression)
    }

    private func load() async {
        guard let api = session.api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            log = try await api.jobLog(projectId: projectId, jobId: job.id)
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
