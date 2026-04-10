import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum GuildAdsBannerStyle: Sendable {
    /// Automatically selects the best available style: glass, then vibrant material, then white.
    case automatic
    /// Glass material background (iOS 26+, macOS 26+).
    case glass
    /// Thin vibrant material background.
    case material
    /// Solid white card background with dark text.
    case white
    /// Solid black card background with light text.
    case black
}

private enum GuildAdsBannerLayout {
    static let maxWidth: CGFloat = 360
    static let height: CGFloat = 50
    static let adRailWidth: CGFloat = 20
}

private enum GuildAdsBannerAssets {
    static let markURL = URL(string: "https://guildads.com/banner-icon.png")!
    static let learnURL = URL(string: "https://guildads.com")!
}

private struct GuildAdsBannerPalette {
    let textColor: Color
    let subtitleColor: Color
    let cardFillColor: Color
    let cardStrokeColor: Color
    let railFillColor: Color
    let railForegroundColor: Color

    /// Whether the card background should use a system material instead of `cardFillColor`.
    let usesGlass: Bool
    let usesVibrantMaterial: Bool

    static let glass = GuildAdsBannerPalette(
        textColor: .primary,
        subtitleColor: .secondary,
        cardFillColor: .clear,
        cardStrokeColor: Color.white.opacity(0.25),
        railFillColor: Color.primary.opacity(0.28),
        railForegroundColor: Color(white: 0.96),
        usesGlass: true,
        usesVibrantMaterial: false
    )

    static let material = GuildAdsBannerPalette(
        textColor: .primary,
        subtitleColor: .secondary,
        cardFillColor: .clear,
        cardStrokeColor: Color.primary.opacity(0.12),
        railFillColor: Color.primary.opacity(0.28),
        railForegroundColor: Color(white: 0.96),
        usesGlass: false,
        usesVibrantMaterial: true
    )

    static let white = GuildAdsBannerPalette(
        textColor: .black,
        subtitleColor: Color.black.opacity(0.6),
        cardFillColor: .white,
        cardStrokeColor: Color.black.opacity(0.12),
        railFillColor: Color.black.opacity(0.28),
        railForegroundColor: Color.white.opacity(0.94),
        usesGlass: false,
        usesVibrantMaterial: false
    )

    static let black = GuildAdsBannerPalette(
        textColor: .white,
        subtitleColor: Color.white.opacity(0.7),
        cardFillColor: .black,
        cardStrokeColor: Color.white.opacity(0.16),
        railFillColor: Color.white.opacity(0.34),
        railForegroundColor: Color.black.opacity(0.88),
        usesGlass: false,
        usesVibrantMaterial: false
    )
}

public struct GuildAdsBanner: View {
    private let placementID: String
    private let style: GuildAdsBannerStyle

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = GuildAdsBannerViewModel()

    public init(placementID: String, style: GuildAdsBannerStyle = .automatic) {
        self.placementID = placementID
        self.style = style
    }

    public var body: some View {
        VStack {
            if let ad = viewModel.ad {
                Button {
                    openAd(ad, source: "tap")
                } label: {
                    bannerCard(for: ad)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        openAd(ad, source: "contextMenu")
                    } label: {
                        Label("Get \(ad.title)", systemImage: "arrow.up.forward.square")
                    }

                    Link(destination: GuildAdsBannerAssets.learnURL) {
                        Label("Learn about Guild Ads", systemImage: "info.circle")
                    }
                }
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
            viewModel.beginAppearance()
            Task {
                await viewModel.reportImpressionIfNeeded(placementID: placementID, theme: resolvedTheme)
            }
        }
        .onChange(of: viewModel.ad?.id) { _ in
            Task {
                await viewModel.reportImpressionIfNeeded(placementID: placementID, theme: resolvedTheme)
            }
        }
    }

    private func openAd(_ ad: GuildAd, source: String) {
        let tapURL = ad.tapURL

        #if DEBUG
        print("[GuildAds] Banner \(source) for placement '\(placementID)', ad '\(ad.id)'")
        print("[GuildAds] tapURL=\(tapURL.absoluteString)")
        print("[GuildAds] destinationURL=\(ad.destinationURL.absoluteString)")
        print("[GuildAds] clickURL=\(ad.clickURL?.absoluteString ?? "nil")")
        #endif

        guard ad.isTapURLLikelyValid else {
            #if DEBUG
            print("[GuildAds] Blocked \(source): URL failed validation: \(tapURL.absoluteString)")
            #endif
            return
        }

        #if canImport(UIKit)
        guard UIApplication.shared.canOpenURL(tapURL) else {
            #if DEBUG
            print("[GuildAds] Blocked \(source): canOpenURL returned false for \(tapURL.absoluteString)")
            #endif
            return
        }
        #endif

        openURL(tapURL) { accepted in
            #if DEBUG
            if !accepted {
                print("[GuildAds] openURL rejected \(source) URL: \(tapURL.absoluteString)")
            }
            #endif
        }
        viewModel.handleTap(placementID: placementID)
    }

    private var resolvedTheme: GuildAdsTheme {
        switch resolvedStyle {
        case .black:
            return .dark
        case .white:
            return .light
        case .glass, .material:
            return colorScheme == .dark ? .dark : .light
        case .automatic:
            return colorScheme == .dark ? .dark : .light
        }
    }

    private var resolvedStyle: GuildAdsBannerStyle {
        guard case .automatic = style else { return style }

        if #available(iOS 26, macOS 26, *) {
            return .glass
        }
        #if canImport(UIKit)
        return .material
        #else
        return .white
        #endif
    }

    private var palette: GuildAdsBannerPalette {
        switch resolvedStyle {
        case .glass:
            return .glass
        case .material:
            return .material
        case .white:
            return .white
        case .black:
            return .black
        case .automatic:
            return .white
        }
    }

    private func bannerCard(for ad: GuildAd) -> some View {
        HStack(spacing: 12) {
            iconView(for: ad)

            adTextView(for: ad)

            Spacer(minLength: 2)

            Text("Get")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.14), radius: 3, x: 0, y: 1)
        }
        .padding(12)
        .padding(.trailing, 20)
        .frame(maxWidth: GuildAdsBannerLayout.maxWidth)
        .frame(minHeight: GuildAdsBannerLayout.height, maxHeight: GuildAdsBannerLayout.height)
        .background {
            cardBackground
        }
        .contentShape(Rectangle())
        .clipped()
        .overlay(alignment: .trailing) {
            adRailView
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        if palette.usesGlass {
            if #available(iOS 26, macOS 26, *) {
                shape
                    .fill(.ultraThinMaterial)
                    .glassEffect(.regular.interactive(), in: shape)
                    .overlay(shape.stroke(palette.cardStrokeColor, lineWidth: 1))
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(shape.stroke(palette.cardStrokeColor, lineWidth: 1))
            }
        } else if palette.usesVibrantMaterial {
            shape
                .fill(.thinMaterial)
                .overlay(shape.stroke(palette.cardStrokeColor, lineWidth: 1))
        } else {
            shape
                .fill(palette.cardFillColor)
                .overlay(shape.stroke(palette.cardStrokeColor, lineWidth: 1))
        }
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
    private var impressionReportedAdID: String?

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

    func beginAppearance() {
        impressionReportedAdID = nil
    }

    func reportImpressionIfNeeded(placementID: String, theme: GuildAdsTheme) async {
        guard let currentAd = ad else {
            return
        }

        guard impressionReportedAdID != currentAd.id else {
            return
        }

        #if DEBUG
        print("[GuildAds] Banner appearance side effect for placement '\(placementID)'")
        #endif

        impressionReportedAdID = currentAd.id

        #if DEBUG
        print("[GuildAds] Reporting impression for '\(placementID)'")
        #endif
        let updatedAd = await GuildAds.reportBannerAppearance(ad: currentAd, placementID: placementID, theme: theme)
        self.ad = updatedAd
        impressionReportedAdID = updatedAd?.id ?? currentAd.id
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
