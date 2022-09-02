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
                    
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.title3.weight(.bold))
                        .padding(.horizontal)
                        .background(
                            Color.orange
                                .frame(height: 40)
                                .cornerRadius(10)
                        )
                    
                    if let numComments {
                        
                        Label(String(numComments), systemImage: "bubble.right.fill")
                            .font(.title3.weight(.bold))
                            .padding(.horizontal)
                            .background(
                                Color.orange
                                    .frame(height: 40)
                                    .cornerRadius(10)
                            )
                        
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
        
        //        VStack {
        //            if url != nil {
        //                if let downloadedImageURL {
        //                    AsyncImage(url: downloadedImageURL) { image in
        //                        image
        //                            .resizable()
        //                            .scaledToFill()
        //                            .frame(height: 200)
        //                            .cornerRadius(1)
        //                            .onTapGesture {
        //                                vm.selectedStory = storyObject
        //                            }
        //                    } placeholder: {
        //                        ProgressView()
        //                    }
        //
        //                } else {
        //                    ZStack {
        //                        ProgressView()
        //                    }
        //                    .frame(height: 200)
        //                    .cornerRadius(12)
        //                }
        //            }
        //
        //
        //
        //            dateAndScoreLabels
        //
        //            VStack(alignment: .leading) {
        //
        //                storyTitle
        //
        //                userAndCommentsLabels
        //
        //            }
        //            .padding(.horizontal)
        //
        //        }
        //        .background(.white)
        //        .cornerRadius(12)
        //        .padding(.horizontal)
        //        .padding(.vertical, 5)
        //        .task {
        //            if let url {
        //                downloadedImageURL = await vm.getImage(from: url)
        //            }
        //        }
    }
}




//struct PostListView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        PostListView(vm: MainViewModel(), title: "The effictiveness of the SwiftUI Codable Protocol is unparalleled", url: "google.com", author: "skrillex", points: 12, numComments: 245, id: "456", storyDate: 909090)
//            .preferredColorScheme(.dark)
//    }
//}
