//
//  SFSafariViewWrapper.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/31/22.
//

import Foundation
import SwiftUI
import SafariServices

struct SFSafariViewWrapper: UIViewControllerRepresentable {
    
    let url: URL
    var onFinish: (() -> Void)? = nil
    
    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onFinish: (() -> Void)?
        
        init(onFinish: (() -> Void)?) {
            self.onFinish = onFinish
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onFinish?()
        }
    }
    
    var safariViewController: SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        return controller
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let controller = safariViewController
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        return
    }
}
