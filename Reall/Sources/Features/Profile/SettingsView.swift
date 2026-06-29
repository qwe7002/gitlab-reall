import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session

    @State private var pushEnabled = PushConfiguration.isEnabled
    @State private var workerURLText = PushConfiguration.workerURL?.absoluteString ?? ""
    @State private var statusMessage: String?

    @State private var isInstallingHooks = false
    @State private var hookSummary: String?

    var body: some View {
        Form {
            Section {
                Toggle("Push Notifications", isOn: $pushEnabled)
                if pushEnabled {
                    TextField("https://your-worker.workers.dev", text: $workerURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save & Register") { Task { await applyPushSettings() } }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Receive CI pipeline, merge request, and mention notifications through your own Cloudflare Worker — without GitLab emails. See the project README for how to deploy the Worker and wire up a GitLab webhook.")
            }

            if pushEnabled {
                Section("Status") {
                    LabeledContent("Permission", value: authStatusText)
                    LabeledContent("Device token",
                                   value: session.pushManager.deviceToken == nil ? "Not registered" : "Registered")
                    if let error = session.pushManager.lastError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    if let statusMessage {
                        Text(statusMessage).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if session.pushManager.webhookSecret != nil {
                    Section {
                        Button {
                            Task { await installHooks() }
                        } label: {
                            HStack {
                                Label("Install on all my projects", systemImage: "bolt.badge.automatic")
                                Spacer()
                                if isInstallingHooks { ProgressView() }
                            }
                        }
                        .disabled(isInstallingHooks)
                        if let hookSummary {
                            Text(hookSummary).font(.caption).foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Auto-register webhooks")
                    } footer: {
                        Text("Reall installs the webhook on your GitLab projects for you, using the GitLab API. Projects where you aren't a maintainer are skipped. You can also toggle individual projects from each project's page.")
                    }
                }
            }

            Section("Account") {
                if let creds = session.credentials {
                    LabeledContent("Host", value: creds.host.absoluteString)
                }
                if let user = session.currentUser {
                    LabeledContent("Signed in as", value: "@\(user.username)")
                }
            }

            Section {
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await session.pushManager.refreshAuthorizationStatus() }
        .onChange(of: pushEnabled) { _, enabled in
            if !enabled {
                PushConfiguration.isEnabled = false
                Task { await session.pushManager.unregister() }
            }
        }
    }

    private var authStatusText: String {
        switch session.pushManager.authorizationStatus {
        case .authorized: return "Granted"
        case .denied: return "Denied"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        default: return "Not requested"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func applyPushSettings() async {
        let trimmed = workerURLText.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            statusMessage = "Enter a valid Worker URL (https://…)."
            return
        }
        PushConfiguration.workerURL = url
        PushConfiguration.isEnabled = true

        let granted = await session.pushManager.requestAuthorization()
        if !granted {
            statusMessage = "Notification permission was not granted."
            return
        }
        if let host = session.credentials?.host, let user = session.currentUser {
            await session.pushManager.registerIfAuthorized(host: host, user: user)
            statusMessage = "Registered with Worker."
        }
    }

    private func installHooks() async {
        guard let api = session.api,
              let service = session.pushManager.webhookService(api: api) else {
            hookSummary = "Register with the Worker first."
            return
        }
        isInstallingHooks = true
        defer { isInstallingHooks = false }
        let summary = await service.installOnAllProjects()
        var parts = ["\(summary.installed) installed"]
        if summary.skippedNoPermission > 0 { parts.append("\(summary.skippedNoPermission) skipped (no access)") }
        if summary.failed > 0 { parts.append("\(summary.failed) failed") }
        hookSummary = parts.joined(separator: " · ") + " of \(summary.total) projects."
    }
}
