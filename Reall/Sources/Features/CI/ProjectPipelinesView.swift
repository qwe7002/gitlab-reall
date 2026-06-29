import SwiftUI

struct ProjectPipelinesView: View {
    @Environment(AppSession.self) private var session
    let project: GitLabProject
    @State private var loader: PaginatedLoader<GitLabPipeline>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(
                    loader: loader,
                    emptyTitle: "No pipelines",
                    emptyMessage: "This project hasn't run any pipelines yet.",
                    emptyImage: "bolt.slash"
                ) { pipeline in
                    NavigationLink(value: Route.pipeline(projectId: project.id,
                                                          pipeline: pipeline,
                                                          projectName: project.nameWithNamespace)) {
                        PipelineRow(pipeline: pipeline)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Pipelines")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabPipeline> { try await api.pipelines(projectId: project.id, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct PipelineRow: View {
    let pipeline: GitLabPipeline

    var body: some View {
        let status = CIStatus(pipeline.status)
        HStack(spacing: 12) {
            Image(systemName: status.symbolName)
                .font(.title3)
                .foregroundStyle(Theme.ciColor(status))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("#\(pipeline.id)").font(.subheadline.weight(.semibold))
                    StatusBadge(status.label, color: Theme.ciColor(status))
                }
                HStack(spacing: 8) {
                    if let ref = pipeline.ref {
                        Label(ref, systemImage: "arrow.triangle.branch").lineLimit(1)
                    }
                    if let sha = pipeline.sha {
                        Text(String(sha.prefix(8))).monospaced()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                RelativeDateText(date: pipeline.updatedAt ?? pipeline.createdAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
