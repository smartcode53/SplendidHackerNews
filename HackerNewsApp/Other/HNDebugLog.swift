import Foundation

enum HNDebugLog {
    static func log(_ message: String) {
        #if DEBUG
        print("[HNWrite] \(message)")
        #endif
    }

    static func error(_ message: String) {
        #if DEBUG
        print("[HNWrite][Error] \(message)")
        #endif
    }
}
