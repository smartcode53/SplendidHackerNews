//
//  WebView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/31/22.
//

import Foundation
import SwiftUI
import WebKit

struct HtmlStringView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
        
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator()
    }
    
    class WebViewCoordinator: NSObject, WKNavigationDelegate {
        
    }
}
