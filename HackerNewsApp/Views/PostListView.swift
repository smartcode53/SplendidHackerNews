//
//  PostListView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/18/22.
//

import SwiftUI

struct PostListView: View {
    
    @StateObject var vm = PostListViewModel()
    @State var downloadedImageURL: URL?
    @Binding var selectedStory: Story?
    
    @State var points: Int
    @State var numComments: Int?
    
    let title: String
    let url: String?
    let author: String
    let id: String
    let storyDate: Int
    let story: Story
    
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
                    Text(Date.getTimeInterval(with: storyDate))
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
                        .frame(maxWidth: .infinity, maxHeight: 200)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 200)
                
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
                    
                    if let numComments {
                        NavigationLink {
                            CommentsView(story: story, numComments: $numComments, points: $points, urlDomain: vm.urlDomain)
                        } label: {
                            Label(String(numComments), systemImage: "bubble.right.fill")
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

extension PostListView {
    
    init(selectedStory: Binding<Story?>, item: Story) {
        self._selectedStory = Binding(projectedValue: selectedStory)
        self._points = State(initialValue: item.points)
        self._numComments = State(initialValue: item.numComments)
        self.title = item.title
        self.url = item.url
        self.author = item.author
        self.id = item.id
        self.storyDate = item.createdAtI
        self.story = item
    }
    
}




//struct PostListView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        PostListView(vm: MainViewModel(), title: "The effictiveness of the SwiftUI Codable Protocol is unparalleled", url: "google.com", author: "skrillex", points: 12, numComments: 245, id: "456", storyDate: 909090)
//            .preferredColorScheme(.dark)
//    }
//}
