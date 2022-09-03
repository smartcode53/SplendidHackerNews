//
//  PostListView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/18/22.
//

import SwiftUI

struct PostListView: View {
    
    @ObservedObject var vm: MainViewModel
    @State var downloadedImageURL: URL?
    @State var urlDomain: String?
    
    let storyObject: Story
    
    let title: String
    let url: String?
    let author: String
    let points: Int
    let numComments: Int?
    let id: String
    let storyDate: Int
    
    
    
    var body: some View {
        
        VStack {
            
            VStack(alignment: .leading, spacing: 0) {
                
                // Domain Name
                if let urlDomain {
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
                            vm.selectedStory = storyObject
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
            if let downloadedImageURL {
                AsyncImage(url: downloadedImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .frame(height: 200)
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
                    
                    
                    
                    
                    if let numComments {
                        NavigationLink {
                            CommentsView(vm: vm, storyTitle: title, storyAuthor: author, points: points, totalCommentCount: numComments, storyDate: storyDate, storyId: id, storyUrl: url ?? nil)
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
                urlDomain = vm.getUrlDomain(for: url)
            }
            
        }
        .task {
            if let url {
                downloadedImageURL = await vm.getImage(from: url)
            }
        }
    }
}




//struct PostListView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        PostListView(vm: MainViewModel(), title: "The effictiveness of the SwiftUI Codable Protocol is unparalleled", url: "google.com", author: "skrillex", points: 12, numComments: 245, id: "456", storyDate: 909090)
//            .preferredColorScheme(.dark)
//    }
//}
