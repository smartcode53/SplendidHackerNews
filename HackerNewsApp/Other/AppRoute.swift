import Foundation

enum AppRoute: Hashable {
    case comments(Story)
    case reader(Story)
    case history
#if DEBUG
    case hnAccount
    case hnDiagnostics
    case readerPreview
#endif
}
