//
//  CommentsButtonView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 8/25/22.
//

import SwiftUI

struct CommentsButtonView: View {
    
    let commentsCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: "text.bubble.fill")
                .font(.title3.weight(.heavy))
            
            Text(String(commentsCount))
                .font(.headline.weight(.heavy))
            
        }
        .padding()
        .background(.orange)
        .cornerRadius(12)
        .foregroundColor(.white)
    }
}

struct CommentsButtonView_Previews: PreviewProvider {
    static var previews: some View {
        CommentsButtonView(commentsCount: 25)
    }
}
