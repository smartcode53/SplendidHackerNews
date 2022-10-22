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
    
    var safariViewController: SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = .white
        controller.preferredBarTintColor = UIColor(named: "DarkBlue")
        controller.dismissButtonStyle = .close
        return controller
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        return safariViewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        return
    }
}
