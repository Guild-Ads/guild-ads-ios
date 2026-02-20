import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum GuildAdsTheme: String, Codable, Sendable {
    case automatic
    case light
    case dark
}

struct LaunchRequestPayload: Codable, Sendable {
    let appToken: String
    let sdkVersion: String
    let timestamp: Int64
    let userID: String?
    let app: AppMetadataPayload
    let device: DeviceMetadataPayload

    enum CodingKeys: String, CodingKey {
        case appToken = "app_token"
        case sdkVersion = "sdk_version"
        case timestamp = "ts"
        case userID = "user_id"
        case app
        case device
    }
}

struct ServeRequestPayload: Codable, Sendable {
    let appToken: String
    let appID: String
    let placementID: String
    let sdkVersion: String
    let os: String
    let osMajor: Int
    let osVersion: String
    let locale: String
    let theme: String
    let userID: String?
    let deviceModel: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case appToken = "app_token"
        case appID = "app_id"
        case placementID = "placement_id"
        case sdkVersion = "sdk_version"
        case os
        case osMajor = "os_major"
        case osVersion = "os_version"
        case locale
        case theme
        case userID = "user_id"
        case deviceModel = "device_model"
        case appVersion = "app_version"
    }
}

struct ImpressionRequestPayload: Codable, Sendable {
    let adID: String
    let placementID: String
    let appToken: String
    let appID: String
    let nonce: String?
    let timestamp: Int64
    let userID: String?
    let osVersion: String
    let locale: String

    enum CodingKeys: String, CodingKey {
        case adID = "ad_id"
        case placementID = "placement_id"
        case appToken = "app_token"
        case appID = "app_id"
        case nonce
        case timestamp = "ts"
        case userID = "user_id"
        case osVersion = "os_version"
        case locale
    }
}

struct ClickRequestPayload: Codable, Sendable {
    let adID: String
    let placementID: String
    let appToken: String
    let appID: String
    let timestamp: Int64
    let userID: String?

    enum CodingKeys: String, CodingKey {
        case adID = "ad_id"
        case placementID = "placement_id"
        case appToken = "app_token"
        case appID = "app_id"
        case timestamp = "ts"
        case userID = "user_id"
    }
}

struct AppMetadataPayload: Codable, Sendable {
    let bundleID: String
    let name: String
    let version: String
    let build: String

    enum CodingKeys: String, CodingKey {
        case bundleID = "bundle_id"
        case name
        case version
        case build
    }
}

struct DeviceMetadataPayload: Codable, Sendable {
    let os: String
    let osVersion: String
    let osMajor: Int
    let locale: String
    let timezone: String
    let model: String

    enum CodingKeys: String, CodingKey {
        case os
        case osVersion = "os_version"
        case osMajor = "os_major"
        case locale
        case timezone
        case model
    }
}

struct LaunchResponsePayload: Decodable {
    let ads: [String: ServeResponsePayload]?
}

struct ImpressionResponsePayload: Decodable {
    let ad: ServeResponsePayload?
}

struct ServeEnvelopeResponsePayload: Decodable {
    let ad: ServeResponsePayload?
}

struct ServeResponsePayload: Codable, Sendable {
    struct CreativePayload: Codable, Sendable {
        let headline: String?
        let body: String?
        let cta: String?
        let imageURL: URL?
        let sponsoredLabel: String?

        enum CodingKeys: String, CodingKey {
            case headline
            case body
            case cta
            case imageURL = "image_url"
            case sponsoredLabel = "sponsored_label"
        }
    }

    struct DestinationPayload: Codable, Sendable {
        let type: String?
        let value: URL?
    }

    struct ReportingPayload: Codable, Sendable {
        let impressionURL: URL?
        let clickURL: URL?

        enum CodingKeys: String, CodingKey {
            case impressionURL = "impression_url"
            case clickURL = "click_url"
        }
    }

    let adID: String?
    let placementID: String?
    let title: String?
    let subtitle: String?
    let iconURL: URL?
    let destinationURL: URL?
    let sponsoredLabel: String?
    let expiry: Date?
    let nonce: String?
    let creative: CreativePayload?
    let destination: DestinationPayload?
    let reporting: ReportingPayload?

    enum CodingKeys: String, CodingKey {
        case adID = "ad_id"
        case placementID = "placement_id"
        case title
        case subtitle
        case iconURL = "icon_url"
        case destinationURL = "destination_url"
        case sponsoredLabel = "sponsored_label"
        case expiry
        case nonce
        case creative
        case destination
        case reporting
    }

    func toGuildAd(defaultPlacementID: String) -> GuildAd? {
        guard let adID else {
            return nil
        }

        let resolvedDestination = destination?.value ?? destinationURL ?? reporting?.clickURL
        guard let resolvedDestination else {
            return nil
        }

        let resolvedTitle = title ?? creative?.headline ?? "Sponsored"
        let resolvedSubtitle = subtitle ?? creative?.body ?? "Discover this app"
        let resolvedIcon = iconURL ?? creative?.imageURL
        let resolvedSponsoredLabel = sponsoredLabel ?? creative?.sponsoredLabel ?? "Sponsored"

        return GuildAd(
            id: adID,
            placementID: placementID ?? defaultPlacementID,
            title: resolvedTitle,
            subtitle: resolvedSubtitle,
            iconURL: resolvedIcon,
            destinationURL: resolvedDestination,
            sponsoredLabel: resolvedSponsoredLabel,
            nonce: nonce,
            expiry: expiry,
            clickURL: reporting?.clickURL
        )
    }
}

struct RuntimeContext: Sendable {
    let token: String
    let sdkVersion: String
    let bundleID: String
    let appName: String
    let appVersion: String
    let buildNumber: String
    let osVersion: String
    let osMajor: Int
    let localeIdentifier: String
    let timezoneIdentifier: String
    let deviceModel: String
    let userID: String?

    static func current(token: String, sdkVersion: String) -> RuntimeContext {
        let bundle = Bundle.main
        let bundleID = bundle.bundleIdentifier ?? "unknown.bundle"
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "Unknown"
        let appVersion = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
        let buildNumber = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"

        let version = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        return RuntimeContext(
            token: token,
            sdkVersion: sdkVersion,
            bundleID: bundleID,
            appName: appName,
            appVersion: appVersion,
            buildNumber: buildNumber,
            osVersion: osVersion,
            osMajor: version.majorVersion,
            localeIdentifier: Locale.current.identifier,
            timezoneIdentifier: TimeZone.current.identifier,
            deviceModel: currentDeviceModel(),
            userID: currentUserID()
        )
    }

    var launchPayload: LaunchRequestPayload {
        LaunchRequestPayload(
            appToken: token,
            sdkVersion: sdkVersion,
            timestamp: nowTimestamp,
            userID: userID,
            app: AppMetadataPayload(
                bundleID: bundleID,
                name: appName,
                version: appVersion,
                build: buildNumber
            ),
            device: DeviceMetadataPayload(
                os: "ios",
                osVersion: osVersion,
                osMajor: osMajor,
                locale: localeIdentifier,
                timezone: timezoneIdentifier,
                model: deviceModel
            )
        )
    }

    func servePayload(placementID: String, theme: GuildAdsTheme) -> ServeRequestPayload {
        ServeRequestPayload(
            appToken: token,
            appID: bundleID,
            placementID: placementID,
            sdkVersion: sdkVersion,
            os: "ios",
            osMajor: osMajor,
            osVersion: osVersion,
            locale: localeIdentifier,
            theme: theme.rawValue,
            userID: userID,
            deviceModel: deviceModel,
            appVersion: appVersion
        )
    }

    func impressionPayload(for ad: GuildAd, placementID: String) -> ImpressionRequestPayload {
        ImpressionRequestPayload(
            adID: ad.id,
            placementID: placementID,
            appToken: token,
            appID: bundleID,
            nonce: ad.nonce,
            timestamp: nowTimestamp,
            userID: userID,
            osVersion: osVersion,
            locale: localeIdentifier
        )
    }

    func clickPayload(for ad: GuildAd, placementID: String) -> ClickRequestPayload {
        ClickRequestPayload(
            adID: ad.id,
            placementID: placementID,
            appToken: token,
            appID: bundleID,
            timestamp: nowTimestamp,
            userID: userID
        )
    }

    private var nowTimestamp: Int64 {
        Int64(Date().timeIntervalSince1970)
    }
}

private func currentUserID() -> String? {
    #if canImport(UIKit)
    return UIDevice.current.identifierForVendor?.uuidString
    #else
    return nil
    #endif
}

private func currentDeviceModel() -> String {
    #if canImport(UIKit)
    return UIDevice.current.model
    #else
    return "unknown"
    #endif
}
