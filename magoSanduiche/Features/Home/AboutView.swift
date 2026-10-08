//
//  AboutView.swift
//  magoSanduiche
//
//  Created by Cursor on 04/05/26.
//

import Foundation
import SwiftUI

struct AboutView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var body: some View {
        AppLayout(background: .gradient, scrollable: true) {
            VStack(alignment: .leading, spacing: 18) {
                header

                linksPanel

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    thanksLine

                    backButton
                }
            }
        }
        .onAppear {
            AppAnalytics.screen("About")
        }
        .enableInjection()
    }

    #if DEBUG
        @ObserveInjection var forceRedraw
    #endif

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("nan_about_readme_kicker")
                .font(.monocraft(relativeTo: .caption, weight: .semibold))
                .foregroundStyle(Color.terminalMana)
            Text("nan_about_title")
                .font(.monocraft(relativeTo: .title3, weight: .bold))
                .foregroundStyle(Color.accent)
                .fixedSize(horizontal: false, vertical: true)
            Text("nan_about_subtitle")
                .font(.monocraft(relativeTo: .callout))
                .foregroundStyle(Color.terminalMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var systemPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            AboutKeyValueRow(key: String(localized: "nan_about_key_app"), value: appName)
            AboutKeyValueRow(
                key: String(localized: "nan_about_key_version"),
                value: String(format: String(localized: "nan_about_version_value"), appVersion, appBuild)
            )
            AboutKeyValueRow(key: String(localized: "nan_about_key_engine"), value: String(localized: "nan_about_engine_value"))
            AboutKeyValueRow(key: String(localized: "nan_about_key_platform"), value: String(localized: "nan_about_platform_value"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // .background(Color.terminalSurface)
        .drawBorder(String(localized: "nan_about_sys_info_border"), color: .accent, lineWidth: 1)
    }

    private var creditsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            AboutKeyValueRow(key: String(localized: "nan_about_key_design"), value: "Enzo Enrico")
            AboutKeyValueRow(key: String(localized: "nan_about_key_code"), value: "Enzo Enrico")
            AboutKeyValueRow(key: String(localized: "nan_about_key_dungeon_master"), value: String(localized: "nan_about_value_dungeon_master"))
            AboutKeyValueRow(key: String(localized: "nan_about_key_font"), value: "Monocraft")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // .background(Color.terminalSurface)
        .drawBorder(String(localized: "nan_about_credits_border"), color: .terminalMana, lineWidth: 1)
    }

    private var linksPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            AboutLinkRow(
                title: String(localized: "nan_about_link_website_key"),
                value: String(localized: "nan_about_link_website_value"),
                valueColor: .terminalMana,
                accessibilityHint: String(localized: "nan_about_link_website_a11y"),
                action: { open(.website) }
            )
            AboutLinkRow(
                title: String(localized: "nan_about_link_feedback_key"),
                value: String(localized: "nan_about_link_feedback_value"),
                valueColor: .accent,
                accessibilityHint: String(localized: "nan_about_link_feedback_a11y"),
                action: { open(.feedback(version: appVersion, build: appBuild)) }
            )
            AboutLinkRow(
                title: String(localized: "nan_about_link_coffee_key"),
                value: String(localized: "nan_about_link_coffee_value"),
                valueColor: .terminalWarning,
                accessibilityHint: String(localized: "nan_about_link_coffee_a11y"),
                isEnabled: AboutOutboundLink.coffeeEnabled,
                action: { open(.coffee) }
            )
            Text("nan_about_links_hint")
                .font(.monocraft(relativeTo: .caption))
                .foregroundStyle(Color.terminalMutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .drawBorder(String(localized: "nan_about_links_border"), color: .terminalWarning, lineWidth: 1)
    }

    private func open(_ link: AboutOutboundLink) {
        guard let url = link.url else { return }
        AppAnalytics.capture("about_link_opened", properties: ["link": link.analyticsName])
        openURL(url)
    }

    private var thanksLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("nan_about_thanks")
                .font(.monocraft(relativeTo: .callout, weight: .semibold))
                .foregroundStyle(Color.terminalWarning)
            BlinkingCursor()
                .accessibilityHidden(true)
        }
        .padding(.top, 4)
    }

    private var backButton: some View {
        Button {
            TerminalMotion.perform(reduceMotion: reduceMotion, animation: TerminalMotion.panelAnimation) {
                coordinator.back()
            }
        } label: {
            Text("nan_about_back")
                .font(.monocraft(relativeTo: .headline, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(OnboardingPrimaryButtonStyle())
        .accessibilityHint(String(localized: "nan_about_back_a11y"))
    }

    private var appName: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        return name ?? "Mago Sanduiche"
    }

    private var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.1"
    }

    private var appBuild: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "0"
    }
}

private struct AboutKeyValueRow: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("> \(key)")
                .font(.monocraft(relativeTo: .caption, weight: .bold))
                .foregroundStyle(Color.terminalMutedText)
                .frame(minWidth: 110, alignment: .leading)
            Text(value)
                .font(.monocraft(relativeTo: .callout, weight: .semibold))
                .foregroundStyle(Color.accent)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AboutLinkRow: View {
    let title: String
    let value: String
    let valueColor: Color
    let accessibilityHint: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("> \(title)")
                    .font(.monocraft(relativeTo: .caption, weight: .bold))
                    .foregroundStyle(Color.terminalMutedText)
                    .frame(minWidth: 110, alignment: .leading)
                Text(value)
                    .font(.monocraft(relativeTo: .callout, weight: .semibold))
                    .foregroundStyle(valueColor)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if isEnabled {
                    Text(">>")
                        .font(.monocraft(relativeTo: .caption, weight: .bold))
                        .foregroundStyle(Color.terminalMana)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(TerminalSubtleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityHint(accessibilityHint)
    }
}

/// About destinations: the site, a direct email, and the PayPal.Me tip page.
private enum AboutOutboundLink {
    /// Tip link stays listed, but the row does not open PayPal until this is turned back on.
    static let coffeeEnabled = false

    case website
    case feedback(version: String, build: String)
    case coffee

    var analyticsName: String {
        switch self {
        case .website:
            "website"
        case .feedback:
            "feedback"
        case .coffee:
            "coffee"
        }
    }

    var url: URL? {
        switch self {
        case .website:
            URL(string: "https://enzoenrico.com")
        case .feedback(let version, let build):
            Self.feedbackURL(version: version, build: build)
        case .coffee:
            URL(string: "https://paypal.me/enzoenrico")
        }
    }

    private static func feedbackURL(version: String, build: String) -> URL? {
        let subject = String(localized: "nan_about_feedback_subject")
        let body = String(
            format: String(localized: "nan_about_feedback_body"),
            locale: Locale.current,
            version,
            build
        )
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=? #")
        guard
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed)
        else {
            return nil
        }
        return URL(string: "mailto:hello@enzoenrico.com?subject=\(encodedSubject)&body=\(encodedBody)")
    }
}

#Preview {
    AboutView()
        .environment(AppCoordinator())
}
