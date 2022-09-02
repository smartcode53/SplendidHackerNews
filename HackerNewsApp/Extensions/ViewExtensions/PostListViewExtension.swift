//
//  PostListViewExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation
import SwiftUI

extension PostListView {
    
//    var image: some View {
//        
//        
//        
//        RoundedRectangle(cornerRadius: 12)
//            .fill(.thickMaterial)
//            .frame(height: 200)
//            .overlay {
//                if let urlDomain = vm.getUrlDomain(for: url) {
//                    VStack {
//                        HStack {
//                            Label(urlDomain, systemImage: "arrow.up.forward.app")
//                                .font(.caption.weight(.medium))
//                                .padding(5)
//                                .background(.orange.opacity(0.4))
//                                .cornerRadius(4)
//                                .padding()
//                                .clipped()
//
//                            Spacer()
//                        }
//
//                        Spacer()
//
//                    }
//                }
//            }
//        
//    }
    
    var dateAndScoreLabels: some View {
        HStack {
            
            Text(Date.getTimeInterval(with: storyDate))
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
    
    var storyTitle: some View {
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
            
            if let numComments {
                NavigationLink {
                    CommentsView(vm: vm, storyTitle: title, storyAuthor: author, points: points, totalCommentCount: numComments, storyDate: storyDate, storyId: id, storyUrl: url)
                } label: {
                    commentsButton
                        .foregroundStyle(.primary)
                }
            } else {
                commentsButton
                    .foregroundStyle(.primary)
            }
            
            
            
        }
        .padding(.bottom)
        .font(.subheadline)
    }
    
    var commentsButton: some View {
        HStack {
            Image(systemName: "text.bubble.fill")
                .font(.title3.weight(.heavy))
            
            Text(String(numComments ?? 0))
                .font(.headline.weight(.heavy))
            
        }
        .padding()
        .background(.black)
        .cornerRadius(12)
        .foregroundColor(.orange)
    }
}
