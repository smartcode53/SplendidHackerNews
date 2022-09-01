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
    
    let storyObject: Story
    
    let title: String
    let url: String
    let author: String
    let points: Int
    let numComments: Int
    let id: String
    let storyDate: Int
    
    
    var body: some View {
        VStack {
            
            if let safeUrl = downloadedImageURL {
                AsyncImage(url: safeUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .cornerRadius(12)
                        .onTapGesture {
                            vm.selectedStory = storyObject
                        }
                } placeholder: {
                    ProgressView()
                }
                
            } else {
                EmptyView()
            }
                
            
            dateAndScoreLabels
            
            VStack(alignment: .leading) {
                
                storyTitle
                
                userAndCommentsLabels
                
            }
            .padding(.horizontal)
            
        }
        .background(.white)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 5)
        .task {
            downloadedImageURL = await vm.getImage(from: url)
//            await vm.getImage(from: url)
        }
    }
}




//struct PostListView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        PostListView(vm: MainViewModel(), storyObject: , title: "The effictiveness of the SwiftUI Codable Protocol is unparalleled", url: "google.com", author: "skrillex", points: 12, numComments: 245, id: "456", storyDate: "29894899")
//    }
//}
