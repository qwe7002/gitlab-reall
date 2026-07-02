import SwiftUI

struct ProfileView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        NavigationStack {
            Group {
                if let user = session.currentUser {
                    List {
                        Section { UserHeader(user: user) }
                        Section {
                            NavigationLink {
                                MyProjectsView()
                            } label: {
                                Label("My Projects", systemImage: "folder.fill")
                            }
                        }
                        Section {
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Label("Settings", systemImage: "gearshape.fill")
                            }
                        }
                        Section {
                            Button(role: .destructive) {
                                session.signOut()
                            } label: {
                                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Profile")
            .navigationDestination(for: Route.self) { $0.destination }
        }
    }
}

/// Reusable header showing identity + stats.
struct UserHeader: View {
    let user: GitLabUser

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                AvatarView(url: user.avatarURL, fallbackText: user.displayName, size: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.displayName).font(.title3.bold())
                    Text("@\(user.username)").font(.subheadline).foregroundStyle(.secondary)
                    if let jobTitle = user.jobTitle, !jobTitle.isEmpty {
                        Text(jobTitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let bio = user.bio, !bio.isEmpty {
                Text(bio).font(.subheadline)
            }
            HStack(spacing: 16) {
                if let location = user.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                }
                if let org = user.organization, !org.isEmpty {
                    Label(org, systemImage: "building.2")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if user.followers != nil || user.following != nil {
                HStack(spacing: 16) {
                    if let followers = user.followers {
                        Label("\(followers) followers", systemImage: "person.2")
                    }
                    if let following = user.following {
                        Text("\(following) following")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Read-only profile for any other user.
struct UserProfileView: View {
    let user: GitLabUser
    var body: some View {
        List { Section { UserHeader(user: user) } }
            .navigationTitle(user.username)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// The signed-in user's own projects.
struct MyProjectsView: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabProject>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader, emptyTitle: "No projects", emptyImage: "folder") { project in
                    NavigationLink(value: Route.project(project)) { ProjectRow(project: project) }
                }
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .navigationTitle("My Projects")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabProject> { try await api.myProjects(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}
