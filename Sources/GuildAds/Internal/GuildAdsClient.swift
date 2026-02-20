import Foundation

private enum FlushOutcome {
    case success
    case retryLater
    case drop
}

actor GuildAdsClient {
    private let configuration: GuildAdsConfiguration
    private let api: GuildAdsAPI
    private let cacheStore: GuildAdsAdCacheStore
    private let queueStore: GuildAdsQueueStore
    private let reachability: GuildAdsReachabilityMonitor

    private var started = false
    private var isFlushing = false

    init(
        configuration: GuildAdsConfiguration,
        api: GuildAdsAPI? = nil,
        cacheStore: GuildAdsAdCacheStore = GuildAdsAdCacheStore(),
        queueStore: GuildAdsQueueStore = GuildAdsQueueStore(),
        reachability: GuildAdsReachabilityMonitor = GuildAdsReachabilityMonitor()
    ) {
        self.configuration = configuration
        self.api = api ?? GuildAdsAPI(configuration: configuration)
        self.cacheStore = cacheStore
        self.queueStore = queueStore
        self.reachability = reachability
    }

    func start() async {
        guard !started else {
            return
        }

        started = true

        reachability.onOnline = { [weak self] in
            guard let self else {
                return
            }

            Task {
                await self.flushQueuedCalls()
            }
        }

        reachability.start()

        await reportLaunch()

        for placementID in configuration.prefetchPlacements {
            _ = await refreshAd(for: placementID, theme: .automatic)
        }

        await flushQueuedCalls()
    }

    func cachedAd(for placementID: String) async -> GuildAd? {
        await cacheStore.ad(for: placementID)
    }

    func refreshAd(for placementID: String, theme: GuildAdsTheme) async -> GuildAd? {
        let context = RuntimeContext.current(token: configuration.token, sdkVersion: configuration.sdkVersion)
        let payload = context.servePayload(placementID: placementID, theme: theme)

        if !reachability.isReachable {
            await enqueue(.serve(payload))
            return await cacheStore.ad(for: placementID)
        }

        do {
            let ad = try await api.fetchAd(payload)
            if let ad {
                await cacheStore.upsert(ad)
                return ad
            }

            await cacheStore.remove(placementID: placementID)
            return nil
        } catch {
            if shouldQueue(error) {
                await enqueue(.serve(payload))
            }
            return await cacheStore.ad(for: placementID)
        }
    }

    func reportBannerAppearance(ad: GuildAd, placementID: String, theme: GuildAdsTheme) async -> GuildAd? {
        let context = RuntimeContext.current(token: configuration.token, sdkVersion: configuration.sdkVersion)
        let impressionPayload = context.impressionPayload(for: ad, placementID: placementID)

        if !reachability.isReachable {
            await enqueue(.impression(impressionPayload))
            await enqueue(.serve(context.servePayload(placementID: placementID, theme: theme)))
            return await cacheStore.ad(for: placementID)
        }

        var updatedAd: GuildAd?

        do {
            updatedAd = try await api.sendImpression(impressionPayload)
            if let updatedAd {
                await cacheStore.upsert(updatedAd)
            }
        } catch {
            if shouldQueue(error) {
                await enqueue(.impression(impressionPayload))
            }
        }

        let refreshed = await refreshAd(for: placementID, theme: theme)
        return refreshed ?? updatedAd ?? ad
    }

    func reportTap(ad: GuildAd, placementID: String) async {
        let context = RuntimeContext.current(token: configuration.token, sdkVersion: configuration.sdkVersion)
        let payload = context.clickPayload(for: ad, placementID: placementID)

        if !reachability.isReachable {
            await enqueue(.click(payload))
            return
        }

        do {
            try await api.sendClick(payload)
        } catch {
            if shouldQueue(error) {
                await enqueue(.click(payload))
            }
        }
    }

    func flushQueuedCalls() async {
        guard !isFlushing else {
            return
        }

        guard reachability.isReachable else {
            return
        }

        isFlushing = true
        defer { isFlushing = false }

        let queuedCalls = await queueStore.all()
        if queuedCalls.isEmpty {
            return
        }

        var successfulIDs = Set<UUID>()

        for call in queuedCalls {
            let outcome = await processQueuedCall(call)
            switch outcome {
            case .success:
                successfulIDs.insert(call.id)
            case .drop:
                successfulIDs.insert(call.id)
            case .retryLater:
                await queueStore.remove(ids: successfulIDs)
                return
            }
        }

        await queueStore.remove(ids: successfulIDs)
    }

    private func reportLaunch() async {
        let payload = RuntimeContext.current(token: configuration.token, sdkVersion: configuration.sdkVersion).launchPayload

        if !reachability.isReachable {
            await enqueue(.launch(payload))
            return
        }

        do {
            let launchAds = try await api.sendLaunch(payload)
            if !launchAds.isEmpty {
                await cacheStore.upsert(launchAds)
            }
        } catch {
            if shouldQueue(error) {
                await enqueue(.launch(payload))
            }
        }
    }

    private func enqueue(_ call: QueuedCall) async {
        await queueStore.enqueue(call, maxCount: configuration.maxQueuedCalls)
    }

    private func processQueuedCall(_ call: QueuedCall) async -> FlushOutcome {
        do {
            switch call.type {
            case .launch:
                guard let launch = call.launch else { return .drop }
                let ads = try await api.sendLaunch(launch)
                if !ads.isEmpty {
                    await cacheStore.upsert(ads)
                }
                return .success

            case .serve:
                guard let serve = call.serve else { return .drop }
                if let ad = try await api.fetchAd(serve) {
                    await cacheStore.upsert(ad)
                }
                return .success

            case .impression:
                guard let impression = call.impression else { return .drop }
                if let ad = try await api.sendImpression(impression) {
                    await cacheStore.upsert(ad)
                }
                return .success

            case .click:
                guard let click = call.click else { return .drop }
                try await api.sendClick(click)
                return .success
            }
        } catch let requestError as GuildAdsRequestError {
            switch requestError {
            case .network, .retryableStatus:
                return .retryLater
            case .invalidURL, .invalidResponse, .unretryableStatus:
                return .drop
            }
        } catch {
            return .retryLater
        }
    }

    private func shouldQueue(_ error: Error) -> Bool {
        if let requestError = error as? GuildAdsRequestError {
            switch requestError {
            case .network, .retryableStatus:
                return true
            case .invalidURL, .invalidResponse, .unretryableStatus:
                return false
            }
        }

        if error is URLError {
            return true
        }

        return false
    }
}
