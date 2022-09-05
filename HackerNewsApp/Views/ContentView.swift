//
//  ContentView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/17/22.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var vm = ContentViewModel()
    @State var selectedStory: Story? = nil
    
    var body: some View {
        NavigationStack {
            
            ZStack {
                
                Color("BackgroundColor")
                    .ignoresSafeArea()
                
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
                        .fill(.primary)
                        .frame(height: 2)
                    
                    ScrollView {
                        posts
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity)
                    .toolbar(.hidden)
                }
            }
        }
        .onAppear {
            vm.loadStories()
        }
    }
}

extension ContentView  {
    
    var posts: some View {
        LazyVStack {
            if let stories = vm.stories {
                ForEach(stories, id: \.self.id) { story in
                    PostListView(selectedStory: $selectedStory, item: story)
                        .shadow(radius: 2)
                }
            } else {
                ProgressView()
            }
        }
        .fullScreenCover(item: $selectedStory) { story in
            if let storyUrl = story.url {
                SafariView(vm: vm, url: storyUrl)
            }
            
        }
    }
}
    

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
