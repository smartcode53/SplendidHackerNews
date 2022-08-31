//
//  WebViewWrapper.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/31/22.
//

import SwiftUI

struct WebViewWrapper: View {
    
    @ObservedObject var vm: MainViewModel
    
    let url: String
    
    var body: some View {
        
        SFSafariViewWrapper(url: vm.returnSafeUrl(url: url))
            .ignoresSafeArea()
            .toolbar(.hidden)
            .accentColor(.orange)
        
//        WebView(url: url)
//            .toolbar {
//                ToolbarItemGroup(placement: .bottomBar) {
//                    HStack {
//
//                        Spacer()
//
//                        Button {
//                            // Do something
//                        } label: {
//                            Image(systemName: "arrow.counterclockwise")
//                        }
//
//                    }
//                }
//            }
//            .navigationBarTitleDisplayMode(.inline)
//            .navigationTitle(vm.getUrlDomain(for: url) ?? "Unknown Domain")
            
    }
}

struct WebViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        WebViewWrapper(vm: MainViewModel(), url: "google.com")
    }
}
