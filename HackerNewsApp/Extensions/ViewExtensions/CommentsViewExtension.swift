//
//  CommentsViewExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation
import SwiftUI

extension CommentsView {
    
    var backButton: some View {
        HStack {
            Image(systemName: "arrow.backward")
                .font(.title.weight(.semibold))
                .onTapGesture {
                    dismiss()
                }
            
            Spacer()
        }
        .padding([.horizontal, .bottom])
    }
    
    var titlePalate: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.getTimeInterval(with: storyDate))
                    .font(.headline)
                    .foregroundColor(.black.opacity(0.5))
                
                Text(storyTitle)
                    .font(.title2.weight(.bold))
                
                if let urlDomain = vm.getUrlDomain(for: storyUrl ?? "https://google.com") {
                    Text(urlDomain)
                        .font(.headline)
                        .foregroundColor(.black.opacity(0.5))
                }
                
                
            }
            
            Spacer()
            
            Image(systemName: "globe.europe.africa.fill")
                .font(.title.weight(.bold))
                .foregroundColor(.black)
        }
        .padding()
        .background(.white)
        .cornerRadius(12)
        .padding(.horizontal)
        .shadow(radius: 4)
        .padding(.bottom)
        .onTapGesture {
            vm.showStoryInComments = true
        }
    }
    
    var metaInfoPalate: some View {
        HStack {
            Label(storyAuthor, systemImage: "person.fill")
            
            Spacer()
            
            Text(points == 1 ? "\(points) Point" : "\(points) points")
            
            Spacer()
            
            Text(totalCommentCount == 1 ? "\(totalCommentCount ?? 0) comment" : "\(totalCommentCount ?? 0) comments")
        }
        .padding()
        .background(.black)
        .foregroundColor(.white)
        .cornerRadius(12)
        .padding(.horizontal)
        .shadow(radius: 4)
    }
    
}
