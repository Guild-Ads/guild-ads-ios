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

- iOS 15+ / macOS 13+
- Swift 5.9+

## Installation

### Swift Package Manager

In Xcode, go to **File > Add Package Dependencies**, paste the repo URL, and click **Add Package**:

```
https://github.com/Guild-Ads/guild-ads-ios
```

Or add it to your `Package.swift`:

```swift
.package(url: "https://github.com/Guild-Ads/guild-ads-ios.git", from: "1.0.1")
```

Then add `"GuildAds"` to the target's dependency list and `import GuildAds` wherever you need it.

## Quick start

Integration is three steps: install the package, configure at launch, add the banner.

### Step 1 — Configure at app launch

Call `GuildAds.configure(token:)` once, before any view appears. The `App` initializer is the right place:

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
```

### Step 2 — Add the banner

Drop `GuildAdsBanner` anywhere in your SwiftUI view hierarchy. Pass a placement ID that describes where in your app the banner lives:

```swift
struct ContentView: View {
    var body: some View {
        VStack {
            // ... your content ...
            Spacer()
            GuildAdsBanner(placementID: "settings_footer")
        }
        .padding()
    }
}
```

The banner handles ad fetching, caching, impression tracking, and offline queueing on its own. If no ad is available, it renders nothing -- your layout won't have a blank gap.

### Step 3 — Get your token from the dashboard

Your SDK token is on the **Publishing** page for your app in the [Guild Ads dashboard](https://guildads.com). Paste it in place of `"YOUR_SDK_TOKEN"` above.

## Placement IDs

A placement ID is a string you choose that identifies where in your app the banner appears. Use `snake_case` and make it descriptive:

```swift
// Good
GuildAdsBanner(placementID: "home_feed_footer")
GuildAdsBanner(placementID: "settings_bottom")
GuildAdsBanner(placementID: "main_tab_inline")

// Avoid
GuildAdsBanner(placementID: "ad")
GuildAdsBanner(placementID: "banner1")
```

You can use multiple placement IDs in the same app -- the SDK fetches and caches each one independently. Pick IDs that will still make sense when you're reading them in your dashboard six months from now.

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

## When there's no fill

If no ad is available for a placement, `GuildAdsBanner` renders an empty `VStack` with no height. Your layout won't have a blank reserved area -- the space collapses naturally. You don't need to do anything special to handle this case.

## Prefetching

Optionally prefetch placements at launch so the banner is ready before it scrolls into view:

```swift
GuildAds.configure(
    token: "YOUR_SDK_TOKEN",
    prefetchPlacements: ["settings_footer", "home_inline"]
)
```

This is optional. The banner will fetch on demand if no cached ad is available.

## UIKit

`GuildAdsBanner` is a SwiftUI view. To use it in a UIKit view controller, host it with `UIHostingController`:

```swift
import UIKit
import SwiftUI
import GuildAds

final class SettingsViewController: UIViewController {
    private var bannerHostingController: UIHostingController<GuildAdsBanner>?

    override func viewDidLoad() {
        super.viewDidLoad()
        embedBanner()
    }

    private func embedBanner() {
        let banner = GuildAdsBanner(placementID: "settings_footer")
        let host = UIHostingController(rootView: banner)

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        bannerHostingController = host
    }
}
```

## App lifecycle

The SDK queues impression and click events when the device is offline and replays them when the network returns. If you want to guarantee the queue is flushed before your app suspends, call `flushPendingCalls()` when the scene moves to the background:

```swift
// SwiftUI
.onChange(of: scenePhase) { phase in
    if phase == .background {
        Task { await GuildAds.flushPendingCalls() }
    }
}

// UIKit (AppDelegate or SceneDelegate)
func sceneDidEnterBackground(_ scene: UIScene) {
    Task { await GuildAds.flushPendingCalls() }
}
```

This is optional -- the queue is also flushed automatically at the next launch.

## Debug logging

In `DEBUG` builds the SDK prints to the console with a `[GuildAds]` prefix:

```
[GuildAds] Banner load for placement 'settings_footer'
[GuildAds] Cached ad for 'settings_footer': nil
[GuildAds] No cached ad, refreshing...
[GuildAds] Refreshed ad for 'settings_footer': Acme App
[GuildAds] Reporting impression for 'settings_footer'
```

These messages are stripped from release builds. If you're not seeing ads and want to trace why, run the app in a `DEBUG` scheme and filter the console for `[GuildAds]`.

## Manual ad loading

`GuildAdsBanner` covers most use cases. If you need to load or refresh an ad outside of a SwiftUI view -- for example, to check whether an ad is available before showing a placement -- you can call the SDK directly:

```swift
// Check the on-disk cache (no network call)
let cached = await GuildAds.cachedAd(for: "settings_footer")

// Force a fresh fetch from the network
let fresh = await GuildAds.refreshAd(for: "settings_footer")
```

Both methods return `nil` if no ad is available. Impression and click tracking are handled by `GuildAdsBanner` and are not part of the manual load path.

## API and dashboard

Once you've signed up at [guildads.com](https://guildads.com), your dashboard has full API documentation. The SDK handles all network communication automatically -- you don't need to call the API directly.
