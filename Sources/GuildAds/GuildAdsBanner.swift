import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum GuildAdsBannerTheme: Sendable {
    case automatic
    case light
    case dark
}

private enum GuildAdsBannerLayout {
    static let maxWidth: CGFloat = 360
    static let height: CGFloat = 50
    static let adRailWidth: CGFloat = 20
}

private enum GuildAdsBannerAssets {
    static let markURL = URL(string: "https://guildads.com/banner-icon.png")!
}

private struct GuildAdsBannerPalette {
    let textColor: Color
    let subtitleColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    let ctaForegroundColor: Color
    let ctaBackgroundColor: Color
    let railFillColor: Color
    let railForegroundColor: Color
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
                .dynamicTypeSize(.small ... .xLarge)
                .textCase(nil)
                .multilineTextAlignment(.leading)
                .transaction { transaction in
                    transaction.animation = nil
                }
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

    private var palette: GuildAdsBannerPalette {
        switch resolvedTheme {
        case .dark:
            let text = Color.white
            let background = Color.black
            return GuildAdsBannerPalette(
                textColor: text,
                subtitleColor: text.opacity(0.82),
                cardFillColor: text.opacity(0.18),
                cardStrokeColor: text.opacity(0.14),
                ctaForegroundColor: background,
                ctaBackgroundColor: text,
                railFillColor: text.opacity(0.38),
                railForegroundColor: background.opacity(0.88)
            )
        case .light, .automatic:
            let text = Color.black
            let background = Color.white
            return GuildAdsBannerPalette(
                textColor: text,
                subtitleColor: text.opacity(0.75),
                cardFillColor: text.opacity(0.12),
                cardStrokeColor: text.opacity(0.18),
                ctaForegroundColor: background,
                ctaBackgroundColor: text,
                railFillColor: text.opacity(0.26),
                railForegroundColor: background.opacity(0.94)
            )
        }
    }

    private func bannerCard(for ad: GuildAd) -> some View {
        HStack(spacing: 12) {
            iconView(for: ad)

            adTextView(for: ad)

            Spacer(minLength: 2)

            Text("Get")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.ctaForegroundColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(palette.ctaBackgroundColor)
                .clipShape(Capsule())
        }
        .padding(12)
        .padding(.trailing, 20)
        .frame(maxWidth: GuildAdsBannerLayout.maxWidth)
        .frame(minHeight: GuildAdsBannerLayout.height, maxHeight: GuildAdsBannerLayout.height)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(palette.cardStrokeColor, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .clipped()
        .overlay(alignment: .trailing) {
            adRailView
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func adTextView(for ad: GuildAd) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ad.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textColor)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)

            Text(ad.subtitle)
                .font(.caption)
                .foregroundStyle(palette.subtitleColor)
                .lineLimit(2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
        }
    }

    private var adRailView: some View {
        Rectangle()
            .fill(palette.railFillColor)
            .frame(width: GuildAdsBannerLayout.adRailWidth)
            .frame(maxHeight: .infinity)
            .overlay {
                VStack(spacing: 0) {
                    Text("AD")
                        .font(.caption2)
                        .fontWeight(.bold)
                    GuildAdsBannerMarkView(foreground: palette.railForegroundColor)
                        .frame(width: 16, height: 16)
                }
                .foregroundStyle(palette.railForegroundColor)
                .opacity(0.7)
                .scaleEffect(0.5)
            }
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
                    .symbolRenderingMode(.monochrome)
                    .scaledToFit()
                    .foregroundStyle(palette.textColor)
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

#if canImport(UIKit)
private typealias GuildAdsBannerPlatformImage = UIImage
#elseif canImport(AppKit)
private typealias GuildAdsBannerPlatformImage = NSImage
#endif

private struct GuildAdsBannerMarkView: View {
    let foreground: Color

    @StateObject private var loader = GuildAdsBannerMarkLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(foreground)
            } else {
                Color.clear
            }
        }
        .task {
            await loader.loadIfNeeded()
        }
    }
}

@MainActor
private final class GuildAdsBannerMarkLoader: ObservableObject {
    @Published var image: Image?

    func loadIfNeeded() async {
        guard image == nil else {
            return
        }

        guard let platformImage = await GuildAdsBannerMarkCache.shared.image() else {
            return
        }

        #if canImport(UIKit)
        image = Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        image = Image(nsImage: platformImage)
        #endif
    }
}

private actor GuildAdsBannerMarkCache {
    static let shared = GuildAdsBannerMarkCache()

    private var cachedImage: GuildAdsBannerPlatformImage?
    private let request: URLRequest
    private let session: URLSession
    private let fileURL: URL?

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024,
            diskPath: "com.guildads.banner-icon-cache"
        )
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30

        session = URLSession(configuration: config)
        request = URLRequest(
            url: GuildAdsBannerAssets.markURL,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 15
        )
        fileURL = Self.makeCacheFileURL()
    }

    func image() async -> GuildAdsBannerPlatformImage? {
        if let cachedImage {
            return cachedImage
        }

        if let diskImage = loadDiskImage() {
            cachedImage = diskImage
            return diskImage
        }

        if let cachedResponse = session.configuration.urlCache?.cachedResponse(for: request),
           let cacheImage = Self.decodeImage(from: cachedResponse.data) {
            cachedImage = cacheImage
            persistToDisk(cachedResponse.data)
            return cacheImage
        }

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                return nil
            }

            guard let networkImage = Self.decodeImage(from: data) else {
                return nil
            }

            session.configuration.urlCache?.storeCachedResponse(
                CachedURLResponse(response: response, data: data),
                for: request
            )
            persistToDisk(data)
            cachedImage = networkImage
            return networkImage
        } catch {
            return nil
        }
    }

    private func loadDiskImage() -> GuildAdsBannerPlatformImage? {
        guard let fileURL else {
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return Self.decodeImage(from: data)
    }

    private func persistToDisk(_ data: Data) {
        guard let fileURL else {
            return
        }

        let directoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func makeCacheFileURL() -> URL? {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("com.guildads.sdk", isDirectory: true)
            .appendingPathComponent("banner-icon.png")
    }

    private static func decodeImage(from data: Data) -> GuildAdsBannerPlatformImage? {
        #if canImport(UIKit)
        return UIImage(data: data)
        #elseif canImport(AppKit)
        return NSImage(data: data)
        #endif
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
