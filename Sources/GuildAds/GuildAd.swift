import Foundation

public struct GuildAd: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let placementID: String
    public let title: String
    public let subtitle: String
    public let iconURL: URL?
    public let destinationURL: URL
    public let nonce: String?
    public let expiry: Date?
    public let clickURL: URL?
    public var tapURL: URL {
        clickURL ?? destinationURL
    }
    public var isTapURLLikelyValid: Bool {
        guard let scheme = tapURL.scheme?.lowercased() else {
            return false
        }

        guard scheme == "http" || scheme == "https" else {
            return false
        }

        guard let host = tapURL.host, !host.isEmpty else {
            return false
        }

        return true
    }

    public init(
        id: String,
        placementID: String,
        title: String,
        subtitle: String,
        iconURL: URL?,
        destinationURL: URL,
        nonce: String? = nil,
        expiry: Date? = nil,
        clickURL: URL? = nil
    ) {
        self.id = id
        self.placementID = placementID
        self.title = title
        self.subtitle = subtitle
        self.iconURL = iconURL
        self.destinationURL = destinationURL
        self.nonce = nonce
        self.expiry = expiry
        self.clickURL = clickURL
    }
}
