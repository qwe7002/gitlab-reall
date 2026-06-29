# Reall

A native **GitLab client for iOS**, built with **SwiftUI**, with a clean,
GitHub-app-style interface. It talks directly to the GitLab REST API v4 (the
same API the `glab` CLI uses) and works with **gitlab.com or any self-hosted
instance**.

A companion **Cloudflare Worker** turns GitLab webhooks into push
notifications, so you can keep an eye on CI without drowning in email.

> Bundle id: `com.qwe7002.reall` · Minimum iOS 17.0

## Features

- 🔐 **Sign in** to gitlab.com or a self-hosted instance with a Personal Access Token (stored in the Keychain).
- 🏠 **Home** — your GitLab activity feed.
- 📥 **My Work** — issues and merge requests assigned to you, filterable by open/closed.
- ⚡️ **CI / CD** — first-class pipeline viewing:
  - latest pipeline status per project at a glance,
  - full pipeline history,
  - pipeline detail with jobs grouped by stage, live auto-refresh while running,
  - **streamed job logs** (ANSI-stripped) with retry/cancel actions.
- 🔎 **Explore** — search projects across your instance; browse starred projects, READMEs, issues and MRs.
- 👤 **Profile & Settings** — your profile, and push-notification configuration.
- 🔔 **Push notifications via your own Cloudflare Worker** — CI failures, MR
  updates, and comments delivered to your device so you can turn GitLab email off.
  **Webhook setup is automatic**: the app installs the GitLab webhooks on your
  projects for you via the API (one tap for all projects, or per-project toggle).

## Project layout

```
.
├── project.yml                 # XcodeGen project definition
├── Reall/
│   ├── Resources/              # Info.plist, entitlements, asset catalog
│   ├── Sources/
│   │   ├── App/                # App entry, AppDelegate (APNs), session, tab bar
│   │   ├── Models/             # Codable GitLab API models
│   │   ├── Networking/         # GitLabAPI client, auth, Keychain
│   │   ├── Push/               # APNs registration + Worker sync
│   │   ├── Shared/             # Reusable views, theme, pagination, navigation
│   │   └── Features/           # Home, MyWork, CI, Explore, Profile
│   └── Tests/                  # Model decoding unit tests
└── cloudflare-worker/          # GitLab webhook → APNs bridge (see its README)
```

## Architecture

- **SwiftUI + `@Observable`** (Observation framework) for state; no third-party dependencies.
- **`async/await`** networking in `GitLabAPI`, with header-based pagination
  surfaced through a generic `PaginatedLoader` / `PagedListView` for infinite scroll.
- **Value-based navigation** via a single `Route` enum.
- **Keychain** for the token; the GitLab host is kept in `UserDefaults`.

## Getting started

The Xcode project is generated with [XcodeGen](https://github.com/yonsson/XcodeGen)
so the `.pbxproj` isn't checked in.

```bash
brew install xcodegen      # if you don't have it
xcodegen generate          # creates Reall.xcodeproj from project.yml
open Reall.xcodeproj
```

Then in Xcode:

1. Select the **Reall** target → **Signing & Capabilities** → choose your team.
   (Update `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` if needed.)
2. Build & run on a device or simulator.
3. On first launch, enter your GitLab host and a Personal Access Token with the
   `api` (or `read_api`) scope.

> Push notifications require a real device and an APNs-capable signing profile.

## Push notifications

See [`cloudflare-worker/README.md`](cloudflare-worker/README.md) for deploying
the Worker and configuring APNs. Once deployed, enable push and paste your
Worker URL in **Profile → Settings → Notifications**, then tap **Install on all
my projects**.

You don't add GitLab webhooks by hand: on registration the Worker issues a
per-user secret, and the app uses the GitLab API to create the webhooks
(authenticated with that secret) on your projects. Individual projects can also
be toggled from their detail page.

## Creating a Personal Access Token

GitLab → **Preferences → Access Tokens** (or `https://<host>/-/user_settings/personal_access_tokens`),
select the `api` scope, and copy the generated `glpat-…` token into the app's
sign-in screen.

## License

BSD 3-Clause — see [LICENSE](LICENSE).
