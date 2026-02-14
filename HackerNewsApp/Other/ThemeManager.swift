import UIKit
import Combine

@MainActor
final class HighContrastTheme {
    static let shared = HighContrastTheme()
    @Published private(set) var isEnabled = false

    private init() {}

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}

@MainActor
final class ThemeManager {
    static let shared = ThemeManager()
    private init() {}

    func apply(settings: Settings, window: UIWindow?) {
        let accent = accentColor(from: settings)
        let fontFamily = Settings.FontFamily(rawValue: settings.fontFamilyRawValue) ?? .system

        UIView.appearance().tintColor = accent
        UISwitch.appearance().onTintColor = accent
        UISegmentedControl.appearance().selectedSegmentTintColor = accent
        UITabBar.appearance().tintColor = accent
        UINavigationBar.appearance().tintColor = accent

        let bodyFont = font(for: fontFamily, textStyle: .body)
        UINavigationBar.appearance().titleTextAttributes = [:]
        UINavigationBar.appearance().largeTitleTextAttributes = [:]
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: bodyFont], for: .normal)

        applyLiveTint(window: window, accent: accent)
    }

    func accentColor(from settings: Settings) -> UIColor {
        color(for: Settings.AccentColor(rawValue: settings.accentColorRawValue) ?? .orange)
    }

    private func color(for accent: Settings.AccentColor) -> UIColor {
        switch accent {
        case .orange:
            return .systemOrange
        case .blue:
            return .systemBlue
        case .green:
            return .systemGreen
        case .red:
            return .systemRed
        case .purple:
            return .systemPurple
        }
    }

    private func font(for family: Settings.FontFamily, textStyle: UIFont.TextStyle) -> UIFont {
        let baseSize = UIFont.preferredFont(forTextStyle: textStyle).pointSize
        let base: UIFont
        switch family {
        case .system:
            base = UIFont.systemFont(ofSize: baseSize)
        case .serif:
            base = UIFont(name: "TimesNewRomanPSMT", size: baseSize) ?? UIFont.systemFont(ofSize: baseSize)
        case .mono:
            base = UIFont.monospacedSystemFont(ofSize: baseSize, weight: .regular)
        }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }

    private func applyLiveTint(window: UIWindow?, accent: UIColor) {
        window?.tintColor = accent
        guard let root = window?.rootViewController else { return }
        applyTint(to: root, accent: accent)
    }

    private func applyTint(to viewController: UIViewController, accent: UIColor) {
        viewController.view.tintColor = accent
        if let nav = viewController as? UINavigationController {
            nav.navigationBar.tintColor = accent
        }
        if let tab = viewController as? UITabBarController {
            tab.tabBar.tintColor = accent
        }
        applyAccent(to: viewController.view, accent: accent)
        for child in viewController.children {
            applyTint(to: child, accent: accent)
        }
        if let presented = viewController.presentedViewController {
            applyTint(to: presented, accent: accent)
        }
    }

    private func applyAccent(to view: UIView, accent: UIColor) {
        if let segmented = view as? UISegmentedControl {
            segmented.selectedSegmentTintColor = accent
        } else if let toggle = view as? UISwitch {
            toggle.onTintColor = accent
        } else if let tabBar = view as? UITabBar {
            tabBar.tintColor = accent
        } else if let navBar = view as? UINavigationBar {
            navBar.tintColor = accent
        }

        for subview in view.subviews {
            applyAccent(to: subview, accent: accent)
        }
    }
}
