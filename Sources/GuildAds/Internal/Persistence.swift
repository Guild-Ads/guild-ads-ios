import Foundation

enum QueuedCallType: String, Codable, Sendable {
    case launch
    case serve
    case impression
    case click
}

struct QueuedCall: Codable, Sendable, Identifiable {
    let id: UUID
    let createdAt: Date
    let type: QueuedCallType
    let launch: LaunchRequestPayload?
    let serve: ServeRequestPayload?
    let impression: ImpressionRequestPayload?
    let click: ClickRequestPayload?

    static func launch(_ payload: LaunchRequestPayload) -> QueuedCall {
        QueuedCall(
            id: UUID(),
            createdAt: Date(),
            type: .launch,
            launch: payload,
            serve: nil,
            impression: nil,
            click: nil
        )
    }

    static func serve(_ payload: ServeRequestPayload) -> QueuedCall {
        QueuedCall(
            id: UUID(),
            createdAt: Date(),
            type: .serve,
            launch: nil,
            serve: payload,
            impression: nil,
            click: nil
        )
    }

    static func impression(_ payload: ImpressionRequestPayload) -> QueuedCall {
        QueuedCall(
            id: UUID(),
            createdAt: Date(),
            type: .impression,
            launch: nil,
            serve: nil,
            impression: payload,
            click: nil
        )
    }

    static func click(_ payload: ClickRequestPayload) -> QueuedCall {
        QueuedCall(
            id: UUID(),
            createdAt: Date(),
            type: .click,
            launch: nil,
            serve: nil,
            impression: nil,
            click: payload
        )
    }
}

private struct CachedAdRecord: Codable, Sendable {
    let ad: GuildAd
    let cachedAt: Date
}

private func guildAdsDataFileURL(directoryURL: URL?, filename: String) -> URL {
    let baseDirectory: URL
    if let directoryURL {
        baseDirectory = directoryURL
    } else {
        baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    return baseDirectory
        .appendingPathComponent("GuildAds", isDirectory: true)
        .appendingPathComponent(filename)
}

actor GuildAdsAdCacheStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cache: [String: CachedAdRecord] = [:]
    private var didLoad = false

    init(directoryURL: URL? = nil) {
        self.fileURL = guildAdsDataFileURL(directoryURL: directoryURL, filename: "ad-cache.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func ad(for placementID: String) -> GuildAd? {
        ensureLoaded()

        guard let record = cache[placementID] else {
            return nil
        }

        if let expiry = record.ad.expiry, expiry <= Date() {
            cache[placementID] = nil
            persist()
            return nil
        }

        return record.ad
    }

    func upsert(_ ad: GuildAd) {
        ensureLoaded()
        cache[ad.placementID] = CachedAdRecord(ad: ad, cachedAt: Date())
        persist()
    }

    func upsert(_ ads: [String: GuildAd]) {
        ensureLoaded()
        for pair in ads {
            cache[pair.key] = CachedAdRecord(ad: pair.value, cachedAt: Date())
        }
        persist()
    }

    func remove(placementID: String) {
        ensureLoaded()
        cache[placementID] = nil
        persist()
    }

    private func ensureLoaded() {
        guard !didLoad else {
            return
        }

        didLoad = true

        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([String: CachedAdRecord].self, from: data) else {
            cache = [:]
            return
        }

        cache = decoded
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Non-fatal cache persistence failure.
        }
    }

}

actor GuildAdsQueueStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var didLoad = false
    private var queue: [QueuedCall] = []

    init(directoryURL: URL? = nil) {
        self.fileURL = guildAdsDataFileURL(directoryURL: directoryURL, filename: "pending-calls.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func enqueue(_ call: QueuedCall, maxCount: Int) {
        ensureLoaded()
        queue.append(call)

        if queue.count > maxCount {
            let overflow = queue.count - maxCount
            queue.removeFirst(overflow)
        }

        persist()
    }

    func all() -> [QueuedCall] {
        ensureLoaded()
        return queue.sorted { $0.createdAt < $1.createdAt }
    }

    func remove(ids: Set<UUID>) {
        ensureLoaded()
        queue.removeAll { ids.contains($0.id) }
        persist()
    }

    private func ensureLoaded() {
        guard !didLoad else {
            return
        }

        didLoad = true

        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([QueuedCall].self, from: data) else {
            queue = []
            return
        }

        queue = decoded
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(queue)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Non-fatal queue persistence failure.
        }
    }
}
