//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI

struct PostView: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @StateObject var vm: UltimatePostViewModel
    @Binding var selectedStory: Story?

    
    
    var body: some View {
        
        if let story = vm.story {
            VStack {
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Domain Name
                    if let urlDomain = story.url?.urlDomain {
                        Text(urlDomain)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.orange)
                            .padding(.bottom, 10)
                        
                    }
                    
                    // Story Title
                    if let storyTitle = story.title {
                        Text(story.url != nil ? "\(storyTitle) \(Image(systemName: "arrow.up.forward.app"))" : "\(storyTitle)")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Color("PostTitle"))
                            .padding(.bottom, 16)
                            .onTapGesture {
                                if story.url != nil {
                                    selectedStory = vm.story
                                }
                                
                            }
                    }
                    
                    
                    // Meta info
                    HStack {
                        Text(Date.getTimeInterval(with: story.time))
                        Text("|")
                            .foregroundColor(Color("DateNameSeparator"))
                        Text(story.by)
                        
                        Spacer()
                    }
                    .foregroundColor(Color("PostDateName"))
                    .padding(.bottom, 16)
                    .font(.subheadline)
                }
                .padding([.horizontal, .top])
                
                // Story Image
                if let imageUrl = vm.imageUrl {
                    AsyncImage(url: imageUrl) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width * 0.977)
                            .frame(height: 220)
                            .clipped()
                    } placeholder: {
                        ProgressView()
                    }
                }
                
                // Points and Actionable Buttons
                VStack {
                    HStack {
                        if let points = story.score {
                            Text(points == 1 ? "\(points) point" : "\(points) points")
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        //Bookmark Button
                        Button {
                            let bookmark = Bookmark(story: story)
                            globalSettings.tempBookmarks.append(bookmark)
                        } label: {
                            Image(systemName: "bookmark")
                                .foregroundColor(.primary)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        
                        // Share Button
                        if let url = story.url {
                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.primary)
                            }
                            .buttonStyle(.bordered)
                        }
                    
                        //Comments Button
                        CommentsButtonView(vm: vm)
                        
                    }
                    .padding()
                }
            }
            .background(Color("CardColor"))
            .cornerRadius(12)
            .padding(.horizontal, 5)
            .task {
                if let url = story.url {
                    vm.loadImage(fromUrl: url)
                }
            }
        }
    }
}

extension PostView {
    init(withStory story: Story, selectedStory: Binding<Story?>) {
        self._vm = StateObject(wrappedValue: UltimatePostViewModel(withStory: story))
        self._selectedStory = selectedStory
    }
}

//struct PostView_Previews: PreviewProvider {
//    static var previews: some View {
//        PostView()
//    }
//}
