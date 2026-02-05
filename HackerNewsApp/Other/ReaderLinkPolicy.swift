import Foundation

enum ReaderLinkPolicy {
    private static let denylistedHosts: Set<String> = [
        "news.ycombinator.com",
        "github.com"
    ]

    private static let blockedExtensions: Set<String> = [
        "pdf", "zip", "png", "jpg", "jpeg", "gif", "webp", "svg", "mp4", "mov"
    ]

    static func canOpenInReader(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }

        if let host = url.host?.lowercased() {
            if denylistedHosts.contains(host) {
                return false
            }
            if denylistedHosts.contains(where: { host.hasSuffix(".\($0)") }) {
                return false
            }
        }

        let pathExtension = url.pathExtension.lowercased()
        if !pathExtension.isEmpty && blockedExtensions.contains(pathExtension) {
            return false
        }

        return true
    }
}
