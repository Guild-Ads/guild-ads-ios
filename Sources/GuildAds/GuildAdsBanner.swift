import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
        VStack {
            if let ad = viewModel.ad {
                Button {
                    let tapURL = ad.tapURL

                    #if DEBUG
                    print("[GuildAds] Banner tap for placement '\(placementID)', ad '\(ad.id)'")
                    print("[GuildAds] tapURL=\(tapURL.absoluteString)")
                    print("[GuildAds] destinationURL=\(ad.destinationURL.absoluteString)")
                    print("[GuildAds] clickURL=\(ad.clickURL?.absoluteString ?? "nil")")
                    #endif

                    guard ad.isTapURLLikelyValid else {
                        #if DEBUG
                        print("[GuildAds] Blocked tap: URL failed validation: \(tapURL.absoluteString)")
                        #endif
                        return
                    }

                    #if canImport(UIKit)
                    guard UIApplication.shared.canOpenURL(tapURL) else {
                        #if DEBUG
                        print("[GuildAds] Blocked tap: canOpenURL returned false for \(tapURL.absoluteString)")
                        #endif
                        return
                    }
                    #endif

                    openURL(tapURL) { accepted in
                        #if DEBUG
                        if !accepted {
                            print("[GuildAds] openURL rejected tap URL: \(tapURL.absoluteString)")
                        }
                        #endif
                    }
                    viewModel.handleTap(placementID: placementID)
                } label: {
                    bannerCard(for: ad)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(ad.title). \(ad.subtitle).")
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

            VStack(alignment: .leading, spacing: 2) {
                Text(ad.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(ad.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }

            Spacer(minLength: 2)

            Text("Get")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
        }
        .padding(12)
        .padding(.trailing, 20)
        .frame(maxWidth: 360)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.white.opacity(0.5))
                .frame(maxWidth: 20, maxHeight: .infinity)
                .overlay {
                    VStack(spacing: 0) {
                        Text("AD")
                            .font(.caption2)
                            .fontWeight(.bold)
                        Image("guild", bundle: .module)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    .foregroundStyle(.black)
                    .opacity(0.7)
                    .scaleEffect(0.5)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func iconView(for ad: GuildAd) -> some View {
        AsyncImage(url: ad.iconURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            default:
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

@MainActor
private final class GuildAdsBannerViewModel: ObservableObject {
    @Published var ad: GuildAd?

    func load(placementID: String, theme: GuildAdsTheme) async {
        #if DEBUG
        print("[GuildAds] Banner load for placement '\(placementID)'")
        #endif

        if ad?.placementID != placementID {
            ad = await GuildAds.cachedAd(for: placementID)
            #if DEBUG
            print("[GuildAds] Cached ad for '\(placementID)': \(ad?.title ?? "nil")")
            #endif
        }

        if ad == nil {
            #if DEBUG
            print("[GuildAds] No cached ad, refreshing...")
            #endif
            ad = await GuildAds.refreshAd(for: placementID, theme: theme)
            #if DEBUG
            print("[GuildAds] Refreshed ad for '\(placementID)': \(ad?.title ?? "nil")")
            #endif
        }
    }

    func onAppear(placementID: String, theme: GuildAdsTheme) async {
        #if DEBUG
        print("[GuildAds] Banner onAppear for placement '\(placementID)'")
        #endif

        await load(placementID: placementID, theme: theme)

        guard let ad else {
            #if DEBUG
            print("[GuildAds] No ad to display for '\(placementID)'")
            #endif
            return
        }

        #if DEBUG
        print("[GuildAds] Reporting impression for '\(placementID)'")
        #endif
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
