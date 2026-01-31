//
//  WebViewWrapper.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/31/22.
//

import SwiftUI

struct SafariView<T>: View where T: SafariViewLoader {
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: T
    
    let url: String?
    
    var body: some View {
        if let url {
            SFSafariViewWrapper(url: vm.returnSafelyLoadedUrl(url: url)) {
                dismiss()
            }
                .ignoresSafeArea()
        }
    }
}

struct WebViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        SafariView(vm: ContentViewModel(), url: "google.com")
    }
}
