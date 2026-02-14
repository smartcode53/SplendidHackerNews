import Foundation

enum LegalLinks {
    static var termsURL: URL? {
        url(forInfoKey: "LegalTermsURL")
    }

    static var privacyURL: URL? {
        url(forInfoKey: "LegalPrivacyURL")
    }

    static var isConfigured: Bool {
        termsURL != nil && privacyURL != nil
    }

    private static func url(forInfoKey key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
