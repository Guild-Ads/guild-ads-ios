import Foundation

public struct GuildAdsEndpoints: Sendable {
    public var launch: String
    public var serve: String
    public var impression: String
    public var click: String

    public init(
        launch: String = "/v1/events/launch",
        serve: String = "/v1/serve",
        impression: String = "/v1/impression",
        click: String = "/v1/events/click"
    ) {
        self.launch = launch
        self.serve = serve
        self.impression = impression
        self.click = click
    }

    public static let `default` = GuildAdsEndpoints()
}

public struct GuildAdsConfiguration: Sendable {
    public var token: String
    public var baseURL: URL
    public var prefetchPlacements: [String]
    public var endpoints: GuildAdsEndpoints
    public var sdkVersion: String
    public var maxQueuedCalls: Int

    public init(
        token: String,
        baseURL: URL = URL(string: "https://guildads.com")!,
        prefetchPlacements: [String] = [],
        endpoints: GuildAdsEndpoints = .default,
        sdkVersion: String = "0.1.0",
        maxQueuedCalls: Int = 500
    ) {
        self.token = token
        self.baseURL = baseURL
        self.prefetchPlacements = prefetchPlacements
        self.endpoints = endpoints
        self.sdkVersion = sdkVersion
        self.maxQueuedCalls = max(1, maxQueuedCalls)
    }
}
