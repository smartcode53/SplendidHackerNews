//
//  UIKitViews.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/29/22.
//

import Foundation
import WebKit
import SwiftUI


struct HTMLView: UIViewRepresentable {
    
    let htmlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlString, baseURL: nil)
    }
}
