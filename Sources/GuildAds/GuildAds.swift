import Foundation
import SwiftUI

@MainActor
public enum GuildAds {
    private static var client: GuildAdsClient?

    public static var isConfigured: Bool {
        client != nil
    }

    public static func configure(
        token: String,
        baseURL: URL = URL(string: "https://guild-ads.onrender.com")!,
        prefetchPlacements: [String] = [],
        endpoints: GuildAdsEndpoints = .default
    ) {
        configure(
            configuration: GuildAdsConfiguration(
                token: token,
                baseURL: baseURL,
                prefetchPlacements: prefetchPlacements,
                endpoints: endpoints
            )
        )
    }

    public static func configure(configuration: GuildAdsConfiguration) {
        let client = GuildAdsClient(configuration: configuration)
        self.client = client

        Task {
            await client.start()
        }
    }

    public static func cachedAd(for placementID: String) async -> GuildAd? {
        guard let client else {
            return nil
        }
        return await client.cachedAd(for: placementID)
    }

    public static func refreshAd(for placementID: String) async -> GuildAd? {
        guard let client else {
            return nil
        }

        return await client.refreshAd(for: placementID, theme: .automatic)
    }

    public static func flushPendingCalls() async {
        guard let client else {
            return
        }

        await client.flushQueuedCalls()
    }

    static func refreshAd(for placementID: String, theme: GuildAdsTheme) async -> GuildAd? {
        guard let client else {
            return nil
        }

        return await client.refreshAd(for: placementID, theme: theme)
    }

    static func reportBannerAppearance(ad: GuildAd, placementID: String, theme: GuildAdsTheme) async -> GuildAd? {
        guard let client else {
            return nil
        }

        return await client.reportBannerAppearance(ad: ad, placementID: placementID, theme: theme)
    }

    static func reportTap(ad: GuildAd, placementID: String) async {
        guard let client else {
            return
        }

        await client.reportTap(ad: ad, placementID: placementID)
    }
}
