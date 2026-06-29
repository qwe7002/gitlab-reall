# Reall Push Worker

A Cloudflare Worker that turns GitLab webhooks into native push notifications
for the [Reall](../README.md) iOS app — so you can disable GitLab email
notifications and still hear about CI failures, merge requests, and mentions.

```
GitLab  ──webhook──▶  Cloudflare Worker  ──APNs──▶  Reall (iOS)
                          │  KV: deviceToken ↔ gitlabUserId
```

## What gets pushed

| GitLab event   | Pushed to                          | When                                   |
| -------------- | ---------------------------------- | -------------------------------------- |
| Pipeline       | the user who triggered it          | `success` / `failed` / `canceled`      |
| Job/Build      | the user who triggered it          | `failed`                               |
| Merge request  | assignees & reviewers / author     | open/update, and merge/close to author |
| Note (comment) | the issue/MR author                | any new comment                        |
| Issue          | assignees                          | any action                             |

Routing lives in `routeEvent()` in [`src/index.ts`](src/index.ts) — tweak it to
match your team's preferences (e.g. only push on pipeline *failures*).

## Prerequisites

- A Cloudflare account and [`wrangler`](https://developers.cloudflare.com/workers/wrangler/) (`npm i -g wrangler`).
- An **APNs Auth Key** (`.p8`) from the Apple Developer portal
  (Certificates, Identifiers & Profiles → Keys → enable *Apple Push Notifications service*).
  Note the **Key ID** and your **Team ID**.

## Setup

```bash
cd cloudflare-worker
npm install

# 1. Create the KV namespace and paste the printed id into wrangler.toml
wrangler kv namespace create DEVICES

# 2. Set secrets
wrangler secret put APNS_AUTH_KEY        # paste the full .p8 file contents
wrangler secret put APNS_KEY_ID          # e.g. ABCDE12345
wrangler secret put APNS_TEAM_ID         # e.g. A1B2C3D4E5
wrangler secret put GITLAB_WEBHOOK_SECRET # any random string

# 3. Adjust vars in wrangler.toml
#    APNS_TOPIC      = your app bundle id (com.qwe7002.reall)
#    APNS_PRODUCTION = "true" for TestFlight/App Store builds, "false" for Xcode debug builds

# 4. Deploy
wrangler deploy
```

This prints your Worker URL, e.g. `https://reall-push.<account>.workers.dev`.

## Wire up GitLab

In each project (or at the group level):
**Settings → Webhooks → Add new webhook**

- **URL**: `https://reall-push.<account>.workers.dev/webhook`
- **Secret token**: the same value you set for `GITLAB_WEBHOOK_SECRET`
- **Trigger**: enable *Pipeline events*, *Job events*, *Merge request events*,
  *Comments*, and/or *Issues events* as desired.

## Wire up the app

In Reall → **Profile → Settings → Notifications**:

1. Toggle **Push Notifications** on.
2. Paste your Worker URL (`https://reall-push.<account>.workers.dev`).
3. Tap **Save & Register** and grant the notification permission.

The app registers its APNs device token against your GitLab user id, and the
Worker delivers matching events from then on. You can now turn off GitLab's
email notifications.

## Endpoints

| Method | Path          | Purpose                                  |
| ------ | ------------- | ---------------------------------------- |
| POST   | `/register`   | Save a device token ↔ GitLab user        |
| POST   | `/unregister` | Remove a device token                    |
| POST   | `/webhook`    | GitLab webhook receiver (auth via token) |
| GET    | `/health`     | Liveness check                           |

## Notes

- APNs auth uses a JWT signed with ES256 via WebCrypto, cached ~50 minutes.
- Invalid/expired device tokens (APNs `400`/`410`) are pruned automatically.
- The Worker stores only an opaque device token, the GitLab host, and the
  numeric user id — no GitLab access token ever leaves the device.
