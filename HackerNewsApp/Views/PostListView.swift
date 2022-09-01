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
            
            image
                .onTapGesture {
                    vm.selectedStory = storyObject
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
    }
}




//struct PostListView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        PostListView(vm: MainViewModel(), storyObject: , title: "The effictiveness of the SwiftUI Codable Protocol is unparalleled", url: "google.com", author: "skrillex", points: 12, numComments: 245, id: "456", storyDate: "29894899")
//    }
//}
