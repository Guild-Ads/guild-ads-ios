import Foundation
import Testing
@testable import GuildAds

@Test func servePayloadMapsToGuildAd() throws {
    let json = """
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
    """

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let payload = try decoder.decode(ServeResponsePayload.self, from: Data(json.utf8))
    let ad = payload.toGuildAd(defaultPlacementID: "settings_footer")

    #expect(ad?.id == "ad_789")
    #expect(ad?.placementID == "settings_footer")
    #expect(ad?.title == "Upgrade your journaling")
    #expect(ad?.destinationURL.absoluteString == "https://example.com/?ref=network")
}

@Test func queueStorePersistsCalls() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = GuildAdsQueueStore(directoryURL: directory)
    await store.enqueue(QueuedCall.launch(sampleLaunchPayload()), maxCount: 10)

    let reloaded = GuildAdsQueueStore(directoryURL: directory)
    let calls = await reloaded.all()

    #expect(calls.count == 1)
    #expect(calls.first?.type == .launch)
}

@Test func cacheStoreRespectsExpiry() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    defer {
        try? FileManager.default.removeItem(at: directory)
    }

    let store = GuildAdsAdCacheStore(directoryURL: directory)

    let expiredAd = GuildAd(
        id: "ad_expired",
        placementID: "settings_footer",
        title: "Old Ad",
        subtitle: "Should not render",
        iconURL: nil,
        destinationURL: URL(string: "https://example.com")!,
        expiry: Date(timeIntervalSinceNow: -60)
    )

    await store.upsert(expiredAd)
    let value = await store.ad(for: "settings_footer")

    #expect(value == nil)
}

private func sampleLaunchPayload() -> LaunchRequestPayload {
    LaunchRequestPayload(
        appToken: "token",
        sdkVersion: "0.1.0",
        timestamp: Int64(Date().timeIntervalSince1970),
        userID: "idfv",
        app: AppMetadataPayload(
            bundleID: "com.example.app",
            name: "Example",
            version: "1.0",
            build: "1"
        ),
        device: DeviceMetadataPayload(
            os: "ios",
            osVersion: "18.0.0",
            osMajor: 18,
            locale: "en_US",
            timezone: "America/Los_Angeles",
            model: "iPhone"
        )
    )
}
