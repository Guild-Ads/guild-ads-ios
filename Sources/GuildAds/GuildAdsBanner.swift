import CryptoKit
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
    static let horizontalPadding: CGFloat = 8
    static let verticalPadding: CGFloat = 5
    static let contentHeight: CGFloat = height - (verticalPadding * 2)
    static let adRailWidth: CGFloat = 20
    static let titleFontSize: CGFloat = 13
    static let subtitleFontSize: CGFloat = 10
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
    private let debugMockAd: GuildAd?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: GuildAdsBannerViewModel

    public init(placementID: String, style: GuildAdsBannerStyle = .automatic) {
        self.placementID = placementID
        self.style = style
        self.previewAd = nil
        self.debugMockAd = GuildAdsBannerDebugMockFactory.make(placementID: placementID)
        _viewModel = StateObject(wrappedValue: GuildAdsBannerViewModel())
    }

    init(previewAd: GuildAd, style: GuildAdsBannerStyle = .automatic) {
        self.placementID = previewAd.placementID
        self.style = style
        self.previewAd = previewAd
        self.debugMockAd = nil
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
            guard !isMockMode else {
                return
            }
            await viewModel.load(placementID: placementID, theme: resolvedTheme)
        }
        .onAppear {
            guard !isMockMode else {
                return
            }
            viewModel.beginAppearance()
            Task {
                await viewModel.reportImpressionIfNeeded(placementID: placementID, theme: resolvedTheme)
            }
        }
        .onChange(of: viewModel.ad?.id) { _ in
            guard !isMockMode else {
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
        guard !isMockMode else {
            return
        }
        viewModel.handleTap(placementID: placementID)
    }

    private var activeAd: GuildAd? {
        previewAd ?? debugMockAd ?? viewModel.ad
    }

    private var isPreviewMode: Bool {
        previewAd != nil
    }

    private var isMockMode: Bool {
        previewAd != nil || debugMockAd != nil
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

    private var bannerShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        .frame(height: GuildAdsBannerLayout.contentHeight, alignment: .center)
        .padding(.horizontal, GuildAdsBannerLayout.horizontalPadding)
        .padding(.vertical, GuildAdsBannerLayout.verticalPadding)
        .padding(.trailing, 20)
        .frame(maxWidth: GuildAdsBannerLayout.maxWidth)
        .frame(height: GuildAdsBannerLayout.height)
        .background {
            cardBackground
        }
        .contentShape(bannerShape)
        #if os(visionOS)
        .contentShape(.hoverEffect, bannerShape)
        #endif
        .clipped()
        .overlay(alignment: .trailing) {
            adRailView
        }
        .clipShape(bannerShape)
        .modifier(GuildAdsBannerGlassEffect(usesGlass: palette.usesGlass, shape: bannerShape))
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = bannerShape
        if palette.usesGlass {
            shape
                .fill(.ultraThinMaterial)
                .overlay(shape.stroke(palette.cardStrokeColor, lineWidth: 1))
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
                font: .system(size: GuildAdsBannerLayout.titleFontSize, weight: .semibold),
                color: palette.textColor,
                measureFont: titleMeasureFont
            )

            Text(ad.subtitle)
                .font(.system(size: GuildAdsBannerLayout.subtitleFontSize))
                .foregroundStyle(palette.subtitleColor)
                .lineLimit(2)
                .lineSpacing(-2)
                .truncationMode(.tail)
                .minimumScaleFactor(0.85)
                .allowsTightening(true)
        }
        .frame(height: GuildAdsBannerLayout.contentHeight, alignment: .center)
        .clipped()
    }

    private var titleMeasureFont: GuildAdsBannerPlatformFont {
        #if canImport(UIKit)
        return UIFont.systemFont(ofSize: GuildAdsBannerLayout.titleFontSize, weight: .semibold)
        #elseif canImport(AppKit)
        return NSFont.systemFont(ofSize: GuildAdsBannerLayout.titleFontSize, weight: .semibold)
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

    private func iconView(for ad: GuildAd) -> some View {
        GuildAdsBannerIconView(url: ad.iconURL, placeholderColor: palette.textColor)
    }
}

private struct GuildAdsBannerGlassEffect: ViewModifier {
    let usesGlass: Bool
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        #if os(visionOS)
        // glassEffect(_:in:) is unavailable on visionOS.
        content
        #else
        if usesGlass, #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content
        }
        #endif
    }
}

private enum GuildAdsBannerDebugMockFactory {
    static func make(placementID: String) -> GuildAd? {
        #if DEBUG
        return GuildAd(
            id: "debug_mock_\(placementID)",
            placementID: placementID,
            title: "Guild Ads",
            subtitle: "The indie-friendly, privacy-respecting ad network",
            iconURL: URL(string: "https://guildads.com/logo-1024.png"),
            destinationURL: URL(string: "https://guildads.com")!
        )
        #else
        return nil
        #endif
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

private struct GuildAdsBannerIconView: View {
    let url: URL?
    let placeholderColor: Color

    @StateObject private var loader = GuildAdsBannerIconLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .symbolRenderingMode(.monochrome)
                    .scaledToFit()
                    .foregroundStyle(placeholderColor)
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            await loader.load(url: url)
        }
    }
}

@MainActor
private final class GuildAdsBannerIconLoader: ObservableObject {
    @Published var image: Image?
    private var loadedURL: URL?

    func load(url: URL?) async {
        guard let url else {
            image = nil
            loadedURL = nil
            return
        }

        if loadedURL == url, image != nil {
            return
        }

        guard let platformImage = await GuildAdsBannerIconCache.shared.image(for: url) else {
            return
        }

        #if canImport(UIKit)
        image = Image(uiImage: platformImage)
        #elseif canImport(AppKit)
        image = Image(nsImage: platformImage)
        #endif
        loadedURL = url
    }
}

private actor GuildAdsBannerIconCache {
    static let shared = GuildAdsBannerIconCache()

    private var memoryCache: [URL: GuildAdsBannerPlatformImage] = [:]
    private let session: URLSession
    private let cacheDirectoryURL: URL?

    init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 32 * 1024 * 1024,
            diskPath: "com.guildads.ad-icon-cache"
        )
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30

        session = URLSession(configuration: config)
        cacheDirectoryURL = Self.makeCacheDirectoryURL()
    }

    func image(for url: URL) async -> GuildAdsBannerPlatformImage? {
        if let cached = memoryCache[url] {
            return cached
        }

        if let diskImage = loadDiskImage(for: url) {
            memoryCache[url] = diskImage
            return diskImage
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 15
        )

        if let cachedResponse = session.configuration.urlCache?.cachedResponse(for: request),
           let cachedImage = Self.decodeImage(from: cachedResponse.data) {
            memoryCache[url] = cachedImage
            persistToDisk(cachedResponse.data, for: url)
            return cachedImage
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
            persistToDisk(data, for: url)
            memoryCache[url] = networkImage
            return networkImage
        } catch {
            return nil
        }
    }

    private func loadDiskImage(for url: URL) -> GuildAdsBannerPlatformImage? {
        guard let fileURL = diskFileURL(for: url),
              let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return Self.decodeImage(from: data)
    }

    private func persistToDisk(_ data: Data, for url: URL) {
        guard let fileURL = diskFileURL(for: url) else {
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

    private func diskFileURL(for url: URL) -> URL? {
        guard let cacheDirectoryURL else {
            return nil
        }

        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hashString = hash.map { String(format: "%02x", $0) }.joined()
        let pathExtension = url.pathExtension
        let filename = pathExtension.isEmpty ? hashString : "\(hashString).\(pathExtension)"
        return cacheDirectoryURL.appendingPathComponent(filename)
    }

    private static func makeCacheDirectoryURL() -> URL? {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("com.guildads.sdk", isDirectory: true)
            .appendingPathComponent("ad-icons", isDirectory: true)
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
#Preview("Guild Ads Sample Creative") {
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

#Preview("Guild Ads Large Text") {
    GuildAdsBanner(previewAd: GuildAdsBannerPreviewFixtures.allAds[0], style: .automatic)
        .dynamicTypeSize(.accessibility5)
        .padding()
        .frame(maxWidth: 420)
}

private enum GuildAdsBannerPreviewFixtures {
    static let allAds: [GuildAd] = [
        GuildAd(
            id: "preview_guild_ads",
            placementID: "preview_guild_ads",
            title: "Guild Ads",
            subtitle: "The indie-friendly, privacy-respecting ad network",
            iconURL: URL(string: "https://guildads.com/logo-1024.png"),
            destinationURL: URL(string: "https://guildads.com")!
        )
    ]
}
#endif
