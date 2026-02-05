import Foundation

enum ReaderLinkResolution {
    case openInReader(url: URL, title: String)
    case showAction(ReaderLinkActionData)
}

struct ReaderLinkActionData {
    let url: URL
    let canOpenInReader: Bool
}

struct ReaderLinkHandler {
    static func resolve(url: URL, prefersReader: Bool, fallbackTitle: String) -> ReaderLinkResolution {
        let canOpenInReader = ReaderLinkPolicy.canOpenInReader(url)
        if prefersReader, canOpenInReader {
            let title = url.host ?? fallbackTitle
            return .openInReader(url: url, title: title)
        }
        return .showAction(ReaderLinkActionData(url: url, canOpenInReader: canOpenInReader))
    }
}
