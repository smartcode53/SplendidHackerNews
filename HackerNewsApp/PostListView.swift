//
//  PostListView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/18/22.
//

import SwiftUI

struct PostListView: View {
    
    @ObservedObject var vm: MainViewModel
    
    let storyObject: Story
    
    let title: String
    let url: String
    let author: String
    let points: Int
    let numComments: Int
    let id: String
    let storyDate: String
    
    var body: some View {
        VStack {
            
            
            
            imagePlaceholder
                .onTapGesture {
                    vm.selectedStory = storyObject
                }
            
            dateAndScoreLabels
            
            VStack(alignment: .leading) {
                
                titleLabel
                
                userAndCommentsLabels
                
            }
            .padding(.horizontal)
            
        }
        .background(.white)
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 5)
    }
}


extension PostListView {
    
    var imagePlaceholder: some View {
        
        RoundedRectangle(cornerRadius: 12)
            .fill(.thickMaterial)
            .frame(height: 200)
            .overlay {
                if let urlDomain = vm.getUrlDomain(for: url) {
                    VStack {
                        HStack {
                            Label(urlDomain, systemImage: "arrow.up.forward.app")
                                .font(.caption.weight(.medium))
                                .padding(5)
                                .background(.orange.opacity(0.4))
                                .cornerRadius(4)
                                .padding()
                                .clipped()
                            
                            Spacer()
                        }
                        
                        Spacer()
                        
                    }
                }
            }

    }
    
    var dateAndScoreLabels: some View {
        HStack {
            
            Text(storyDate)
                .font(.subheadline.weight(.heavy))
            
            Spacer()
            
            Image(systemName: "arrow.up.heart.fill")
                .font(.title2.weight(.heavy))
            
            Text("\(points)")
                .fontWeight(.heavy)
        }
        .font(.headline)
        .padding([.horizontal, .bottom])
        .foregroundColor(.orange)
    }
    
    var titleLabel: some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .minimumScaleFactor(0.5)
            .padding(.bottom, 15)
    }
    
    var userAndCommentsLabels: some View {
        HStack {
            Image(systemName: "person.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("\(author)")
                .foregroundStyle(.secondary)
            
            Spacer()
            
            NavigationLink {
                CommentsView(vm: vm, storyTitle: title, storyAuthor: author, points: points, totalCommentCount: numComments, storyDate: storyDate, storyId: id, storyUrl: url)
            } label: {
                CommentsButtonView(commentsCount: numComments)
                    .foregroundStyle(.primary)
            }
            
            
        }
        .padding(.bottom)
        .font(.subheadline)
    }
}

//struct PostListView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        PostListView(vm: MainViewModel(), storyObject: , title: "The effictiveness of the SwiftUI Codable Protocol is unparalleled", url: "google.com", author: "skrillex", points: 12, numComments: 245, id: "456", storyDate: "29894899")
//    }
//}
