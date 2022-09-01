//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var vm = MainViewModel()
    
    var body: some View {
        NavigationView {
            
            ScrollView {
                if !vm.isLoadingPosts {
                    posts
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Stories")
            .frame(maxWidth: .infinity)
            .background(.orange)
            
        }
        .task {
            await vm.getStories()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
