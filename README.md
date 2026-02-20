# GuildAds Swift SDK

`GuildAds` is a lightweight iOS Swift package for publishers to show banner ads with minimal setup.

## What it does

- One-line SDK initialization at app launch.
- Sends an app-launch event with app/device metadata.
- Caches ad decisions locally by placement.
- Provides `GuildAdsBanner` (drop-in SwiftUI view).
- Reports banner appearances and taps.
- Queues launch/serve/impression/click calls when offline and flushes automatically when connectivity returns.

## Install (Swift Package Manager)

Add this package to your Xcode project, then import `GuildAds`.

## Quick start

```swift
import SwiftUI
import GuildAds

@main
struct DemoApp: App {
    init() {
        GuildAds.configure(token: "YOUR_SDK_TOKEN")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Spacer()
            GuildAdsBanner(placementID: "settings_footer")
        }
        .padding()
    }
}
```

## Default API base URL

`https://guild-ads.onrender.com`

## Default endpoints used by the SDK

- `POST /v1/events/launch`
- `POST /v1/serve`
- `POST /v1/impression`
- `POST /v1/events/click`

You can override endpoint paths in `GuildAds.configure(..., endpoints: ...)`.

## Expected ad response shape

`POST /v1/serve` expects either `204 No Content` or an ad payload shaped like:

```json
{
  "ad_id": "ad_789",
  "placement_id": "settings_footer",
  "creative": {
    "headline": "Upgrade your journaling",
    "body": "A calm, private diary app with powerful search.",
    "image_url": "https://cdn.example.com/creative/ad_789.png",
    "sponsored_label": "Sponsored"
  },
  "destination": {
    "type": "url",
    "value": "https://example.com/?ref=network"
  },
  "reporting": {
    "click_url": "https://guild-ads.onrender.com/r/ad_789"
  },
  "expiry": "2026-02-10T18:00:00Z",
  "nonce": "signed_nonce_here"
}
```

## Initialization prefetch (optional)

You can prefetch specific placements during configure:

```swift
GuildAds.configure(
    token: "YOUR_SDK_TOKEN",
    prefetchPlacements: ["settings_footer", "home_inline"]
)
```
