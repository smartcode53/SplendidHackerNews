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
        NavigationStack {
            
            ZStack {
                
                Color("BackgroundColor")
                
                VStack(spacing: 0) {
                    
                    ZStack {
                        HStack {
                            
                            Text("Stories")
                                .font(.largeTitle.weight(.bold))
                                .underline(true, pattern: .solid, color: .orange)
                            
                            Spacer()
                        }
                        .padding()
                    }
                    .background(Color("CardColor"))
                    
                    Rectangle()
                        .fill(Color("NavigationSeparatorLine"))
                        .frame(height: 2)
                    
                    ScrollView {
                        if !vm.isLoadingPosts {
                            posts
                                .padding(.top)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .toolbar(.hidden)
                }
            }
            
            
            
            
            
            
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
