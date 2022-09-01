//
//  SingleCommentViewExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/1/22.
//

import Foundation
import SwiftUI

extension SingleCommentView {
    
    var commentMetaInfo: some View {
        HStack {
            Text(commentAuthor)
                .padding(.trailing)
            
            Text(Date.getTimeInterval(with: commentDate))
            
            Spacer()
            
            Image(systemName: "chevron.up")
                .rotationEffect(Angle(degrees: !animateArrow ? 180 : 0))
        }
        .font(.callout)
        .foregroundColor(.orange)
        .padding(.bottom, 10)
        .onTapGesture {
            withAnimation(.easeInOut) {
                isExpanded.toggle()
            }
            
        }
    }
}
