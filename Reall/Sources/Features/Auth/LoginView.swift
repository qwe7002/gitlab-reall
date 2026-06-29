import SwiftUI
import UIKit

struct LoginView: View {
    @Environment(AppSession.self) private var session

    @State private var hostText = "https://gitlab.com"
    @State private var token = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 16) {
                        field(title: "GitLab Host",
                              prompt: "https://gitlab.com",
                              text: $hostText,
                              keyboard: .URL)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Personal Access Token")
                                .font(.subheadline.weight(.semibold))
                            SecureField("glpat-…", text: $token)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Text("Create one in GitLab → Settings → Access Tokens with the `api` (or `read_api`) scope.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = session.signInError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In").bold()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!canSubmit || isSubmitting)

                    Link(destination: tokenHelpURL) {
                        Label("How to create a token", systemImage: "questionmark.circle")
                            .font(.footnote)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Reall")
                .font(.largeTitle.bold())
            Text("A GitLab client for iOS")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private func field(title: String, prompt: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var canSubmit: Bool {
        !token.trimmingCharacters(in: .whitespaces).isEmpty && normalizedHost != nil
    }

    private var normalizedHost: URL? {
        var string = hostText.trimmingCharacters(in: .whitespaces)
        if string.isEmpty { return nil }
        if !string.contains("://") { string = "https://" + string }
        guard let url = URL(string: string), url.host != nil else { return nil }
        return url
    }

    private var tokenHelpURL: URL {
        guard let host = normalizedHost else { return URL(string: "https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html")! }
        return host.appendingPathComponent("-/user_settings/personal_access_tokens")
    }

    private func submit() {
        guard let host = normalizedHost else { return }
        isSubmitting = true
        Task {
            await session.signIn(host: host, token: token)
            isSubmitting = false
        }
    }
}
