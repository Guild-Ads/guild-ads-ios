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

## Banner embedding guidance

`GuildAdsBanner` hardens itself against many inherited host styles (for example text case changes, oversized Dynamic Type, and ambient animations), but parent transforms can still affect rendering.

For predictable presentation:

- Avoid wrapping the banner in `scaleEffect`, `rotationEffect`, or parent `opacity` transforms.
- Prefer giving the banner enough horizontal space (it targets a max width of 360pt and fixed height of 50pt).
- Avoid clipping/masking the banner container unless you intentionally want to crop it.

## Default API base URL

`https://guildads.com`

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
    "value": "https://guildads.com/r/ad_789?p=settings_footer&n=signed"
  },
  "reporting": {
    "impression_url": "https://guildads.com/v1/impression"
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
