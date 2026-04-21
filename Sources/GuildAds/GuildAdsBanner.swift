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
    private let previewAd: GuildAd?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: GuildAdsBannerViewModel

    public init(placementID: String, style: GuildAdsBannerStyle = .automatic) {
        self.placementID = placementID
        self.style = style
        self.previewAd = nil
        _viewModel = StateObject(wrappedValue: GuildAdsBannerViewModel())
    }

    init(previewAd: GuildAd, style: GuildAdsBannerStyle = .automatic) {
        self.placementID = previewAd.placementID
        self.style = style
        self.previewAd = previewAd
        _viewModel = StateObject(wrappedValue: GuildAdsBannerViewModel(initialAd: previewAd))
    }

    public var body: some View {
        VStack {
            if let ad = activeAd {
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
            }
        }
        .task(id: placementID) {
            guard !isPreviewMode else {
                return
            }
            await viewModel.load(placementID: placementID, theme: resolvedTheme)
        }
        .onAppear {
            guard !isPreviewMode else {
                return
            }
            viewModel.beginAppearance()
            Task {
                await viewModel.reportImpressionIfNeeded(placementID: placementID, theme: resolvedTheme)
            }
        }
        .onChange(of: viewModel.ad?.id) { _ in
            guard !isPreviewMode else {
                return
            }
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
        guard !isPreviewMode else {
            return
        }
        viewModel.handleTap(placementID: placementID)
    }

    private var activeAd: GuildAd? {
        previewAd ?? viewModel.ad
    }

    private var isPreviewMode: Bool {
        previewAd != nil
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
        HStack(spacing: 0) {
            iconView(for: ad)
                .padding(.trailing, 8)

            adTextView(for: ad)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Text("Get")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.14), radius: 3, x: 0, y: 1)
                .fixedSize(horizontal: true, vertical: true)
        }
        .padding(8)
        .padding(.trailing, 20)
        .frame(maxWidth: GuildAdsBannerLayout.maxWidth)
        .frame(maxHeight: GuildAdsBannerLayout.height)
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
            GuildAdsMarqueeText(
                text: ad.title,
                font: .subheadline.weight(.semibold),
                color: palette.textColor,
                measureFont: titleMeasureFont
            )

            Text(ad.subtitle)
                .font(.caption)
                .foregroundStyle(palette.subtitleColor)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titleMeasureFont: GuildAdsBannerPlatformFont {
        #if canImport(UIKit)
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        return UIFont.systemFont(ofSize: descriptor.pointSize, weight: .semibold)
        #elseif canImport(AppKit)
        return NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        #endif
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

private struct GuildAdsMarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let measureFont: GuildAdsBannerPlatformFont

    private let spacing: CGFloat = 18
    private let pointsPerSecond: CGFloat = 30
    private let pauseDuration: TimeInterval = 3

    @State private var cycleStart = Date()

    var body: some View {
        let stringWidth = text.guildAdsWidth(using: measureFont)
        let stringHeight = text.guildAdsHeight(using: measureFont)
        let gap = max(spacing, stringHeight * 1.5)
        let distance = stringWidth + gap

        return GeometryReader { geo in
            let needsScrolling = stringWidth > geo.size.width

            ZStack(alignment: .leading) {
                if needsScrolling {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                        marqueeTrack(
                            at: context.date,
                            distance: distance,
                            spacing: gap,
                            laneWidth: geo.size.width
                        )
                    }
                } else {
                    baseText
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .onAppear {
                cycleStart = Date()
            }
            .onChange(of: text) { _ in
                cycleStart = Date()
            }
            .onChange(of: geo.size.width) { _ in
                cycleStart = Date()
            }
        }
        .frame(height: stringHeight)
    }

    private var baseText: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
    }

    private var scrollingText: some View {
        baseText
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func marqueeTrack(at date: Date, distance: CGFloat, spacing: CGFloat, laneWidth: CGFloat) -> some View {
        let travelDuration = max(0.1, Double(distance / pointsPerSecond))
        let cycleDuration = pauseDuration + travelDuration
        let elapsed = date.timeIntervalSince(cycleStart)
        let cycleTime = elapsed.truncatingRemainder(dividingBy: cycleDuration)

        let offset: CGFloat
        if cycleTime < pauseDuration {
            offset = 0
        } else {
            let travelTime = cycleTime - pauseDuration
            offset = -min(distance, CGFloat(travelTime) * pointsPerSecond)
        }

        return HStack(spacing: spacing) {
            scrollingText
            scrollingText
        }
        .offset(x: offset)
        .frame(width: laneWidth, alignment: .leading)
        .clipped()
    }
}

private extension String {
    func guildAdsWidth(using font: GuildAdsBannerPlatformFont) -> CGFloat {
        #if canImport(UIKit)
        return (self as NSString).size(withAttributes: [.font: font]).width
        #elseif canImport(AppKit)
        return (self as NSString).size(withAttributes: [.font: font]).width
        #endif
    }

    func guildAdsHeight(using font: GuildAdsBannerPlatformFont) -> CGFloat {
        #if canImport(UIKit)
        return (self as NSString).size(withAttributes: [.font: font]).height
        #elseif canImport(AppKit)
        return (self as NSString).size(withAttributes: [.font: font]).height
        #endif
    }
}

#if canImport(UIKit)
private typealias GuildAdsBannerPlatformImage = UIImage
private typealias GuildAdsBannerPlatformFont = UIFont
#elseif canImport(AppKit)
private typealias GuildAdsBannerPlatformImage = NSImage
private typealias GuildAdsBannerPlatformFont = NSFont
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

    init(initialAd: GuildAd? = nil) {
        self.ad = initialAd
    }

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

#if DEBUG
#Preview("Marquee Demo (Overflow)") {
    GuildAdsBanner(
        previewAd: GuildAd(
            id: "preview_marquee_demo",
            placementID: "preview_marquee_demo",
            title: "This is an intentionally very long banner title to demonstrate marquee scrolling",
            subtitle: "Marquee should move left continuously when title exceeds width.",
            iconURL: nil,
            destinationURL: URL(string: "https://guildads.com")!
        ),
        style: .automatic
    )
    .frame(width: 320)
    .padding()
}

#Preview("All Supabase Campaign Creatives") {
    ScrollView {
        VStack(spacing: 10) {
            ForEach(GuildAdsBannerPreviewFixtures.allAds) { ad in
                GuildAdsBanner(previewAd: ad, style: .automatic)
            }
        }
        .padding()
    }
    .frame(maxWidth: 420)
}

private enum GuildAdsBannerPreviewFixtures {
    static let allAds: [GuildAd] = [
        GuildAd(
            id: "2f7cd11b-880a-4bd2-9ddf-4bf2cff3c0fa",
            placementID: "preview_2f7cd11b",
            title: "Easy Dice",
            subtitle: "Simple modern animated dices",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/65/db/89/65db89f6-375e-fea7-41d4-9bf3ea0da135/AppIcon-0-0-1x_U007epad-0-1-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/easy-dice/id1514806286?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "b91a39b9-efda-423f-91b7-d21caa960672",
            placementID: "preview_b91a39b9",
            title: "Finalist Daily Planner",
            subtitle: "Life Organizer for Home & Away",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/cf/49/f8/cf49f8f8-9dd1-07b5-a0d2-ce29bc7a1272/AppIcon-0-0-1x_U007epad-0-1-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/finalist-daily-planner/id6447014685?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "e5e31c88-ef22-4aec-a796-73e7085cc493",
            placementID: "preview_e5e31c88",
            title: "Nihongo - Japanese Study Tool",
            subtitle: "Camera lookup, smart flashcards, and deep kanji insights",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/7e/5d/47/7e5d47b4-e4fc-a4e6-edf9-df8d6f286053/AppIcon-0-0-1x_U007epad-0-0-0-1-0-0-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/app/apple-store/id881697245?pt=127247052&ct=guild-ads&mt=8") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "1fc7043b-424d-4791-9632-a2948bdc3404",
            placementID: "preview_1fc7043b",
            title: "Rainy Skies",
            subtitle: "Beautiful Weather at a Glance",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/3d/f1/d7/3df1d7c6-cffc-d4ed-c00d-c996e7b00ea5/LiquidGlass1-0-0-1x_U007epad-0-1-0-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/rainy-skies/id1637453069?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "8c90566d-bcef-445a-98cb-fad56fbfe971",
            placementID: "preview_8c90566d",
            title: "Mostly Good Metrics",
            subtitle: "Drop in an SDK, Track events, funnels, and retention.",
            iconURL: URL(string: "https://mostlygoodmetrics.com/images/og-image-icon.png"),
            destinationURL: URL(string: "https://mostlygoodmetrics.com") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "716db9cd-c010-435f-b261-4eed7ef04455",
            placementID: "preview_716db9cd",
            title: "Scoreless",
            subtitle: "Check soccer matches without spoiling the score.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/cc/24/87/cc2487c8-7907-0ea3-61d3-8caf5751f976/AppIcon-0-1x_U007ephone-0-1-0-85-220-0.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/scoreless/id6523435481?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "8600d6df-2253-437d-9df8-fa8fa59deee8",
            placementID: "preview_8600d6df",
            title: "Tripsy: Travel Planner",
            subtitle: "Organize all your trips in one place.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/ef/73/9b/ef739b42-3be2-91b4-6c96-1d90327a7504/App_Icon_Original-0-1x_U007epad-0-0-0-1-0-0-sRGB-85-220-0.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/tripsy-travel-planner/id1429967544?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "7b280370-165c-4868-a0ab-546ed0afb304",
            placementID: "preview_7b280370",
            title: "Thrive: Financial Intelligence",
            subtitle: "Ask. Learn. Grow your money.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/bf/ee/52/bfee52cf-85b2-3b21-a496-c1531153e145/AppIcon-0-0-1x_U007ephone-0-1-0-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/thrive-financial-intelligence/id6741694500?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "cc348edd-8bb9-4a8f-a303-54cdcab0f1b6",
            placementID: "preview_cc348edd",
            title: "Scores for NCAA Sports",
            subtitle: "Stats and scores for most NCAA Division 1,2 and 3 sports",
            iconURL: URL(string: "https://scoresforncaa.com/assets/images/app-store-icon.jpeg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/scores-for-ncaa-sports/id6739069456") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "cbc6f449-bf7b-4a3d-be19-38008729eb65",
            placementID: "preview_cbc6f449",
            title: "Tiny Docs",
            subtitle: "PDF Editing Made Simple.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/25/58/99/25589910-89b6-144f-01b3-538f744fb607/AppIconRed-0-0-1x_U007epad-0-0-0-1-0-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/tiny-docs/id6758741132?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "5cc8d777-7eb9-4079-8101-bedf8285657e",
            placementID: "preview_5cc8d777",
            title: "iCloud Photos & Drive Backup",
            subtitle: "Parachute Backup - Protect Your Precious Memories.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/fa/08/9b/fa089baf-6010-3d33-a89e-b295c9d7e15f/Parachute-iOS-0-0-1x_U007epad-0-1-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/app/apple-store/id6749824842?pt=125087879&ct=ppc-guildads&mt=8") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "1582b656-abb5-4e62-9f51-53074e68b0dc",
            placementID: "preview_1582b656",
            title: "Overcast",
            subtitle: "A very good podcast app.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/89/f0/0f/89f00fac-ab2f-bb30-e772-db3e514e3943/AppIcon-0-0-1x_U007epad-0-1-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/app/apple-store/id888422857?pt=4432800&ct=Guild%20Ads&mt=8") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "73c0fa92-8fc3-459f-888b-edf7cb705732",
            placementID: "preview_73c0fa92",
            title: "App Store",
            subtitle: "Download MTG Scanner - Lion’s Eye by Orlando Gabriel Herrera on the App Store. See screenshots, ratings and reviews, user tips, and more apps like MTG Scanner -…",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/PurpleSource211/v4/48/4e/6c/484e6c32-8f87-6f32-a791-4864afcd95f0/Placeholder.mill/1200x630wa.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/mtg-scanner-lions-eye/id1546754798") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "82ac3fbe-c324-4998-ad66-a6dbde46f0f7",
            placementID: "preview_82ac3fbe",
            title: "Alpenglow: Sunset Predictions",
            subtitle: "Golden Hour Times",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/b6/c7/0f/b6c70ff4-a594-e667-9894-5675ea16776a/AppIcon-0-0-1x_U007epad-0-0-0-1-0-0-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/sunset-predictions-alpenglow/id978589174?uo=4&ct=Guild") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "3e0384da-8569-4478-9ef0-89d767b4a8af",
            placementID: "preview_3e0384da",
            title: "Here 2 There - Instant Navigation",
            subtitle: "Save your favorite places. Get there fast.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/50/0e/16/500e169f-8a61-8566-060f-511c1d205932/Here2ThereIcon-0-0-1x_U007epad-0-1-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/app/apple-store/id6751860553?pt=2108296&ct=guild&mt=8") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "0cbfa1aa-eee9-4cd4-8152-83a84dc5315f",
            placementID: "preview_0cbfa1aa",
            title: "Tethered - rope survival game",
            subtitle: "Don't cut the rope!",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/fb/31/6d/fb316d8c-4ab2-9116-8bbf-4d65b7ff9b7a/TetheredIcon-0-0-1x_U007epad-0-1-0-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/app/apple-store/id6755638434?pt=2108296&ct=guild&mt=8") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "1b584edb-2bfc-465a-9c87-9327a55d33d3",
            placementID: "preview_1b584edb",
            title: "Letters - daily word game",
            subtitle: "Spell words. Earn points. Beat your friends.",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/65/db/c5/65dbc5ae-5bb8-ab2d-57ad-a0ed350c7992/AppIcon-0-0-1x_U007epad-0-1-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/app/apple-store/id6741609921?pt=2108296&ct=guild&mt=8") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "743bd6d8-3379-4a4e-a8e6-851d09dc6b8f",
            placementID: "preview_743bd6d8",
            title: "Tinseltown: Watchlist & Streaming Tracker",
            subtitle: "Find new things to watch and where to watch them",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/71/4c/c3/714cc327-9a90-3da1-983d-287a0ecbf2e2/AppIcon-0-0-1x_U007epad-0-1-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/tinseltown-movie-tv-tracker/id6480349413?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "5be6f944-f447-4ee3-b1b3-49a88deaabf6",
            placementID: "preview_5be6f944",
            title: "Tasks: Todo Lists & Kanban",
            subtitle: "The most customizable and native task manager for Apple's platforms!",
            iconURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/21/59/5a/21595af7-1160-de8f-3b35-0ad2915c26db/AppIcon-0-0-1x_U007epad-0-0-0-1-0-0-sRGB-85-220.png/512x512bb.jpg"),
            destinationURL: URL(string: "https://apps.apple.com/us/app/tasks-todo-lists-kanban/id1502903102?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "0893722b-cdfe-4ac9-8c5a-e620a4a1aed6",
            placementID: "preview_0893722b",
            title: "KeepCount: Tally Counter",
            subtitle: "Fast, tactile scoreboard",
            iconURL: nil,
            destinationURL: URL(string: "https://apps.apple.com/us/app/keepcount-tally-counter/id6758891370?uo=4") ?? URL(string: "https://guildads.com")!
        ),
        GuildAd(
            id: "afa19d0b-e338-40ac-8ee7-d3175e1b1bee",
            placementID: "preview_afa19d0b",
            title: "Sticky Widgets",
            subtitle: "Simple Home Screen notes",
            iconURL: nil,
            destinationURL: URL(string: "https://apps.apple.com/us/app/sticky-widgets/id1533254320?uo=4") ?? URL(string: "https://guildads.com")!
        )
    ]
}
#endif
