import Foundation

enum AppRoute: Hashable {
    case comments(Story)
    case reader(Story)
    case history
    case hnAccount
    case hnDiagnostics
    case readerPreview
}
