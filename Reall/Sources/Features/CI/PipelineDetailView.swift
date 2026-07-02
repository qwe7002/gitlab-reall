import SwiftUI

struct PipelineDetailView: View {
    @Environment(AppSession.self) private var session
    let projectId: Int
    @State var pipeline: GitLabPipeline
    let projectName: String

    @State private var jobs: [GitLabJob] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        List {
            Section { summaryCard }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            ForEach(stages, id: \.self) { stage in
                Section(stage) {
                    ForEach(jobs.filter { ($0.stage ?? "") == stage }) { job in
                        NavigationLink {
                            JobLogView(projectId: projectId, job: job)
                        } label: {
                            JobRow(job: job)
                        }
                        .swipeActions {
                            if CIStatus(job.status).isActive {
                                Button("Cancel", role: .destructive) { Task { await cancel(job) } }
                            } else {
                                Button("Retry") { Task { await retry(job) } }.tint(.blue)
                            }
                        }
                    }
                }
            }

            if isLoading && jobs.isEmpty {
                ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pipeline #\(pipeline.id)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await retryPipeline() }
                    } label: { Label("Retry pipeline", systemImage: "arrow.clockwise") }
                } label: {
                    if isWorking { ProgressView() } else { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .refreshable { await reload() }
        .task(id: pipeline.id) { await reload() }
        .task { await autoRefreshLoop() }
    }

    private var summaryCard: some View {
        let status = CIStatus(pipeline.status)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: status.symbolName)
                    .font(.title)
                    .foregroundStyle(Theme.ciColor(status))
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.label).font(.headline)
                    Text(projectName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                if let ref = pipeline.ref {
                    Label(ref, systemImage: "arrow.triangle.branch").lineLimit(1)
                }
                if let sha = pipeline.shortSHA {
                    Label(sha, systemImage: "number")
                }
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let duration = pipeline.duration {
                    Label(formatDuration(duration), systemImage: "clock")
                }
                if let finished = pipeline.finishedAt {
                    RelativeDateText(date: finished, prefix: "finished ")
                } else if let created = pipeline.createdAt {
                    RelativeDateText(date: created, prefix: "created ")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let user = pipeline.user {
                HStack(spacing: 6) {
                    AvatarView(url: user.avatarURL, fallbackText: user.displayName, size: 20)
                    Text("Triggered by \(user.displayName)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                Label("\(passed) passed", systemImage: "checkmark.circle").foregroundStyle(.green)
                if failed > 0 {
                    Label("\(failed) failed", systemImage: "xmark.octagon").foregroundStyle(.red)
                }
            }
            .font(.caption)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total >= 3600 { return "\(total / 3600)h \((total % 3600) / 60)m" }
        return total >= 60 ? "\(total / 60)m \(total % 60)s" : "\(total)s"
    }

    private var stages: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for job in jobs {
            let stage = job.stage ?? "default"
            if !seen.contains(stage) { seen.insert(stage); ordered.append(stage) }
        }
        return ordered
    }

    private var passed: Int { jobs.filter { CIStatus($0.status) == .success }.count }
    private var failed: Int { jobs.filter { CIStatus($0.status) == .failed }.count }

    private func reload() async {
        guard let api = session.api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let fresh = api.pipeline(projectId: projectId, pipelineId: pipeline.id)
            async let freshJobs = api.pipelineJobs(projectId: projectId, pipelineId: pipeline.id)
            pipeline = try await fresh
            jobs = try await freshJobs
            errorMessage = nil
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Poll while the pipeline is still running so the UI stays live.
    private func autoRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(8))
            guard CIStatus(pipeline.status).isActive else { continue }
            await reload()
        }
    }

    private func retry(_ job: GitLabJob) async {
        await mutate { try await $0.retryJob(projectId: projectId, jobId: job.id) }
    }

    private func cancel(_ job: GitLabJob) async {
        await mutate { try await $0.cancelJob(projectId: projectId, jobId: job.id) }
    }

    private func retryPipeline() async {
        await mutate { try await $0.retryPipeline(projectId: projectId, pipelineId: pipeline.id) }
    }

    private func mutate(_ action: @escaping (GitLabAPI) async throws -> Any) async {
        guard let api = session.api else { return }
        isWorking = true
        defer { isWorking = false }
        _ = try? await action(api)
        await reload()
    }
}

struct JobRow: View {
    let job: GitLabJob

    var body: some View {
        let status = CIStatus(job.status)
        HStack(spacing: 10) {
            Image(systemName: status.symbolName)
                .foregroundStyle(Theme.ciColor(status))
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name).font(.subheadline)
                if let duration = job.duration {
                    Text(formatDuration(duration)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if job.allowFailure == true {
                Text("allowed to fail").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        return total >= 60 ? "\(total / 60)m \(total % 60)s" : "\(total)s"
    }
}
