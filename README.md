# GuildAds Swift SDK

Show a single, tasteful ad in your app. Get paid weekly.

GuildAds is a lightweight ad SDK built for indie apps. No full-screen takeovers, no tracking across apps, no mystery math on your earnings. You add one clearly labeled banner, and payments come straight from what advertisers spend.

**[Sign up at guildads.com](https://guildads.com)** to get your SDK token and start earning.

### What you get as a publisher

- **Weekly payouts** tied directly to advertiser spend -- no opaque ad-tech middlemen.
- **10% bonus credit** on every finalized payment, usable to promote your own apps on the network.
- **Privacy-first** -- no cross-app tracking. The SDK uses hashed, app-scoped identifiers only.
- **One ad slot** that stays out of your users' way, so the upgrade path to an ad-free tier stays clean.

## Requirements

- iOS 15+ / macOS 12+
- Swift 5.9+

## Installation

Add the package in Xcode via **File > Add Package Dependencies** and paste the repo URL, or add it to your `Package.swift`:

```swift
.package(url: "https://github.com/guildads/GuildAdsSDK.git", from: "1.0.0")
```

Then `import GuildAds` wherever you need it.

## Quick start

```swift
import SwiftUI
import GuildAds

@main
struct MyApp: App {
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

That's it. The banner handles loading, caching, impression tracking, and offline queueing on its own.

## Banner styles

Control how the banner looks with the `style` parameter:

| Style | What it does |
|---|---|
| `.automatic` | Picks the best option for the device. Glass on iOS 26+, vibrancy on older iOS, white elsewhere. **This is the default.** |
| `.glass` | Translucent glass material (iOS 26+). |
| `.material` | Thin vibrancy material blur. |
| `.white` | Solid white background, dark text. |
| `.black` | Solid black background, light text. |

```swift
GuildAdsBanner(placementID: "settings_footer", style: .black)
```

In every style the "Get" button is white with a subtle shadow, and the "AD" label strip matches the text color with a punchout appearance.

## Embedding tips

The banner targets 360pt wide and 50pt tall. It guards against inherited text casing, oversized Dynamic Type, and ambient animations, but parent transforms can still affect it.

- Avoid wrapping it in `scaleEffect`, `rotationEffect`, or parent `opacity` modifiers.
- Give it enough horizontal room -- it won't stretch beyond 360pt.
- Don't clip the container unless you want to crop intentionally.

## Prefetching

Optionally prefetch placements at launch so the banner is ready before it appears:

```swift
GuildAds.configure(
    token: "YOUR_SDK_TOKEN",
    prefetchPlacements: ["settings_footer", "home_inline"]
)
```

## API details

Base URL: `https://guildads.com`

| Endpoint | Purpose |
|---|---|
| `POST /v1/events/launch` | App launch event with device metadata |
| `POST /v1/serve` | Fetch an ad decision for a placement |
| `POST /v1/impression` | Report a banner impression |
| `POST /v1/events/click` | Report a tap |

Override paths with `GuildAds.configure(..., endpoints: ...)`.

<details>
<summary>Example <code>/v1/serve</code> response</summary>

Returns `204 No Content` when there's no fill, or:

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

</details>
