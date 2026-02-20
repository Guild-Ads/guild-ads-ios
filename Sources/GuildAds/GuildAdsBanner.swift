import SwiftUI

public enum GuildAdsBannerTheme: Sendable {
    case automatic
    case light
    case dark
}

public struct GuildAdsBanner: View {
    private let placementID: String
    private let theme: GuildAdsBannerTheme

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = GuildAdsBannerViewModel()

    public init(placementID: String, theme: GuildAdsBannerTheme = .automatic) {
        self.placementID = placementID
        self.theme = theme
    }

    public var body: some View {
        Group {
            if let ad = viewModel.ad {
                Button {
                    let destinationURL = ad.destinationURL
                    openURL(destinationURL)
                    viewModel.handleTap(placementID: placementID)
                } label: {
                    bannerCard(for: ad)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(ad.sponsoredLabel), \(ad.title). \(ad.subtitle)")
            }
        }
        .task(id: placementID) {
            await viewModel.load(placementID: placementID, theme: resolvedTheme)
        }
        .onAppear {
            Task {
                await viewModel.onAppear(placementID: placementID, theme: resolvedTheme)
            }
        }
    }

    private var resolvedTheme: GuildAdsTheme {
        switch theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .automatic:
            return colorScheme == .dark ? .dark : .light
        }
    }

    private func bannerCard(for ad: GuildAd) -> some View {
        HStack(spacing: 12) {
            iconView(for: ad)

            VStack(alignment: .leading, spacing: 4) {
                Text(ad.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(ad.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(ad.sponsoredLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    @ViewBuilder
    private func iconView(for ad: GuildAd) -> some View {
        AsyncImage(url: ad.iconURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "app.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.secondary.opacity(0.15))
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
private final class GuildAdsBannerViewModel: ObservableObject {
    @Published var ad: GuildAd?

    func load(placementID: String, theme: GuildAdsTheme) async {
        if ad?.placementID != placementID {
            ad = await GuildAds.cachedAd(for: placementID)
        }

        if ad == nil {
            ad = await GuildAds.refreshAd(for: placementID, theme: theme)
        }
    }

    func onAppear(placementID: String, theme: GuildAdsTheme) async {
        await load(placementID: placementID, theme: theme)

        guard let ad else {
            return
        }

        self.ad = await GuildAds.reportBannerAppearance(ad: ad, placementID: placementID, theme: theme)
    }

    func handleTap(placementID: String) {
        guard let ad else {
            return
        }

        Task {
            await GuildAds.reportTap(ad: ad, placementID: placementID)
        }
    }
}
