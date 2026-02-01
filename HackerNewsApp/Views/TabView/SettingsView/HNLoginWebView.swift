import SwiftUI
import WebKit

struct HNLoginWebView: UIViewRepresentable {
    let onComplete: ([HTTPCookie]) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: "https://news.ycombinator.com/login") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onComplete: ([HTTPCookie]) -> Void
        private var didComplete = false

        init(onComplete: @escaping ([HTTPCookie]) -> Void) {
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url, url.host == "news.ycombinator.com" else { return }
            guard !didComplete else { return }
            if url.path == "/news" || url.path == "/" || url.path == "/item" {
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    self.didComplete = true
                    self.onComplete(cookies)
                }
            }
        }
    }
}
