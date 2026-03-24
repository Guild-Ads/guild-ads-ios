// GuildAdsBannerConfiguration.swift
// GuildAds
//
// Created by Tyler Hillsman

import SwiftUI

public struct GuildAdsBannerConfiguration: Sendable {
    public var cornerRadius: CGFloat
    public var maxWidth: CGFloat
    public var showIcon: Bool
    public var callToActionText: String
    public var showCallToAction: Bool
    public var horizontalPadding: CGFloat

    public init(
        cornerRadius: CGFloat = 14,
        maxWidth: CGFloat = 360,
        showIcon: Bool = true,
        callToActionText: String = "Get",
        showCallToAction: Bool = true,
        horizontalPadding: CGFloat = 12
    ) {
        self.cornerRadius = cornerRadius
        self.maxWidth = maxWidth
        self.showIcon = showIcon
        self.callToActionText = callToActionText
        self.showCallToAction = showCallToAction
        self.horizontalPadding = horizontalPadding
    }

    public static let `default` = GuildAdsBannerConfiguration()
}
