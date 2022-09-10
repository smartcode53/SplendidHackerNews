//
//  PostView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/8/22.
//

import SwiftUI

struct PostView: View {
    
    @StateObject var vm = PostListViewModel()
    @Binding var selectedStory: Story?
    @State var downloadedImageURL: URL?
    
    @State var commentCount: Int?
    @State var points: Int
    
    let story: Story
    let title: String
    let url: String?
    let author: String
    let date: Int
    
    var body: some View {
        
        VStack {
            
            VStack(alignment: .leading, spacing: 0) {
                
                // Domain Name
                if let urlDomain = vm.urlDomain {
                    Text(urlDomain)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.orange)
                        .padding(.bottom, 10)
                    
                }
                
                // Story Title
                Text(url != nil ? "\(title) \(Image(systemName: "arrow.up.forward.app"))" : "\(title)")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Color("PostTitle"))
                    .padding(.bottom, 16)
                    .onTapGesture {
                        if url != nil {
                            selectedStory = story
                        }
                        
                    }
                
                // Meta info
                HStack {
                    Text(Date.getTimeInterval(with: date))
                    Text("|")
                        .foregroundColor(Color("DateNameSeparator"))
                    Text(author)
                    
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
                    Text(points == 1 ? "\(points) point" : "\(points) points")
                        .font(.headline)
                    
                    Spacer()
                    
                    if let url {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up.fill")
                        }
                        .createPressableButton()
                    }
                    
                    if let commentCount {
                        NavigationLink {
                            CommentsView(story: story, numComments: $commentCount, points: $points, urlDomain: vm.urlDomain)
                        } label: {
                            Label(String(commentCount), systemImage: "bubble.right.fill")
                        }
                        .createPressableButton()
                    }
                    
                }
                .padding()
            }
        }
        .background(Color("CardColor"))
        .cornerRadius(12)
        .padding(.horizontal, 5)
        .onAppear {
            if let url {
                vm.loadUrlDomain(forUrl: url)
            }
            
        }
        .task {
            if let url {
                vm.loadImage(fromUrl: url)
            }
        }
    }
}

extension PostView {
    init(story: Story, selectedStory: Binding<Story?>) {
        self._selectedStory = Binding(projectedValue: selectedStory)
        self._commentCount = State(initialValue: story.descendants)
        self._points = State(initialValue: story.score)
        self.title = story.title
        self.url = story.url
        self.author = story.by
        self.date = story.time
        self.story = story
    }
}

//struct PostView_Previews: PreviewProvider {
//    static var previews: some View {
//        PostView()
//    }
//}
