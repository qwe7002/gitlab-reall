import SwiftUI

/// Value-based navigation routes shared across stacks.
enum Route: Hashable {
    case issue(GitLabIssue)
    case mergeRequest(GitLabMergeRequest)
    case project(GitLabProject)
    case pipelines(GitLabProject)
    case pipeline(projectId: Int, pipeline: GitLabPipeline, projectName: String)
    case user(GitLabUser)

    @ViewBuilder @MainActor
    var destination: some View {
        switch self {
        case .issue(let issue):
            IssueDetailView(issue: issue)
        case .mergeRequest(let mr):
            MergeRequestDetailView(mr: mr)
        case .project(let project):
            ProjectDetailView(project: project)
        case .pipelines(let project):
            ProjectPipelinesView(project: project)
        case .pipeline(let projectId, let pipeline, let projectName):
            PipelineDetailView(projectId: projectId, pipeline: pipeline, projectName: projectName)
        case .user(let user):
            UserProfileView(user: user)
        }
    }
}
