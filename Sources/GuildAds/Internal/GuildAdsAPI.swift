import Foundation

enum GuildAdsRequestError: Error, Sendable {
    case invalidURL(String)
    case invalidResponse
    case network(URLError)
    case retryableStatus(Int)
    case unretryableStatus(Int)
}

private struct GuildAdsHTTPResponse: Sendable {
    let statusCode: Int
    let data: Data
}

actor GuildAdsAPI {
    private let configuration: GuildAdsConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: GuildAdsConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()

            // Handle numeric timestamps
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }

            let stringValue = try container.decode(String.self)

            // Handle ISO8601 with fractional seconds (e.g., 2026-02-20T18:30:00.000Z)
            let isoWithFractional = ISO8601DateFormatter()
            isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoWithFractional.date(from: stringValue) {
                return date
            }

            // Handle ISO8601 without fractional seconds (e.g., 2026-02-20T18:30:00Z)
            let isoStandard = ISO8601DateFormatter()
            isoStandard.formatOptions = [.withInternetDateTime]
            if let date = isoStandard.date(from: stringValue) {
                return date
            }

            // Fallback: return distant future rather than failing
            print("[GuildAds] Warning: Could not parse date '\(stringValue)', using distant future")
            return Date.distantFuture
        }
        self.decoder = decoder
    }

    func sendLaunch(_ payload: LaunchRequestPayload) async throws -> [String: GuildAd] {
        let response = try await post(path: configuration.endpoints.launch, body: payload)

        #if DEBUG
        print("[GuildAds] Launch response status: \(response.statusCode), bytes: \(response.data.count)")
        if let jsonString = String(data: response.data, encoding: .utf8) {
            print("[GuildAds] Launch response body: \(jsonString.prefix(500))")
        }
        #endif

        guard !response.data.isEmpty else {
            #if DEBUG
            print("[GuildAds] Launch response empty")
            #endif
            return [:]
        }

        let launch: LaunchResponsePayload
        do {
            launch = try decoder.decode(LaunchResponsePayload.self, from: response.data)
        } catch {
            #if DEBUG
            print("[GuildAds] Failed to decode launch response: \(error)")
            #endif
            return [:]
        }

        guard let payloadAds = launch.ads else {
            #if DEBUG
            print("[GuildAds] Launch response has no ads field")
            #endif
            return [:]
        }

        #if DEBUG
        print("[GuildAds] Launch decoded \(payloadAds.count) ads for placements: \(payloadAds.keys.joined(separator: ", "))")
        #endif

        return payloadAds.reduce(into: [String: GuildAd]()) { result, pair in
            let (placementID, payload) = pair
            if let ad = payload.toGuildAd(defaultPlacementID: placementID) {
                result[placementID] = ad
                #if DEBUG
                print("[GuildAds] Cached ad for placement '\(placementID)': \(ad.title)")
                #endif
            }
        }
    }

    func fetchAd(_ payload: ServeRequestPayload) async throws -> GuildAd? {
        #if DEBUG
        print("[GuildAds] Fetching ad for placement '\(payload.placementID)'")
        #endif

        let response = try await post(path: configuration.endpoints.serve, body: payload)

        #if DEBUG
        print("[GuildAds] Serve response status: \(response.statusCode), bytes: \(response.data.count)")
        #endif

        guard response.statusCode != 204, !response.data.isEmpty else {
            #if DEBUG
            print("[GuildAds] Serve returned no content")
            #endif
            return nil
        }

        #if DEBUG
        if let jsonString = String(data: response.data, encoding: .utf8) {
            print("[GuildAds] Serve response body: \(jsonString.prefix(500))")
        }
        #endif

        if let direct = try? decoder.decode(ServeResponsePayload.self, from: response.data) {
            let ad = direct.toGuildAd(defaultPlacementID: payload.placementID)
            #if DEBUG
            print("[GuildAds] Serve decoded ad: \(ad?.title ?? "nil")")
            #endif
            return ad
        }

        if let wrapped = try? decoder.decode(ServeEnvelopeResponsePayload.self, from: response.data),
           let ad = wrapped.ad?.toGuildAd(defaultPlacementID: payload.placementID) {
            #if DEBUG
            print("[GuildAds] Serve decoded wrapped ad: \(ad.title)")
            #endif
            return ad
        }

        #if DEBUG
        print("[GuildAds] Serve failed to decode response")
        #endif
        return nil
    }

    func sendImpression(_ payload: ImpressionRequestPayload) async throws -> GuildAd? {
        let response = try await post(path: configuration.endpoints.impression, body: payload)

        guard response.statusCode != 204, !response.data.isEmpty else {
            return nil
        }

        if let impression = try? decoder.decode(ImpressionResponsePayload.self, from: response.data),
           let ad = impression.ad?.toGuildAd(defaultPlacementID: payload.placementID) {
            return ad
        }

        if let direct = try? decoder.decode(ServeResponsePayload.self, from: response.data) {
            return direct.toGuildAd(defaultPlacementID: payload.placementID)
        }

        return nil
    }

    func sendClick(_ payload: ClickRequestPayload) async throws {
        _ = try await post(path: configuration.endpoints.click, body: payload)
    }

    private func post<T: Encodable>(path: String, body: T) async throws -> GuildAdsHTTPResponse {
        guard let url = url(for: path) else {
            throw GuildAdsRequestError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.token, forHTTPHeaderField: "X-GuildAds-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw GuildAdsRequestError.invalidResponse
            }

            let statusCode = httpResponse.statusCode
            if statusCode == 204 || (200...299).contains(statusCode) {
                return GuildAdsHTTPResponse(statusCode: statusCode, data: data)
            }

            if statusCode == 429 || statusCode >= 500 {
                throw GuildAdsRequestError.retryableStatus(statusCode)
            }

            throw GuildAdsRequestError.unretryableStatus(statusCode)
        } catch let error as URLError {
            throw GuildAdsRequestError.network(error)
        }
    }

    private func url(for path: String) -> URL? {
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            return absoluteURL
        }

        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return configuration.baseURL.appendingPathComponent(trimmed)
    }
}
