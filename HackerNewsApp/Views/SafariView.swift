//
//  WebViewWrapper.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/31/22.
//

import SwiftUI

struct SafariView: View {
    
    @ObservedObject var vm: MainViewModel
    
    let url: String?
    
    var body: some View {
        VStack {
            if let url {
                SFSafariViewWrapper(url: vm.returnSafeUrl(url: url))
                    .ignoresSafeArea()
                    .toolbar(.hidden)
            }
        }
        
        
            
    }
}

struct WebViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        SafariView(vm: MainViewModel(), url: "google.com")
    }
}
