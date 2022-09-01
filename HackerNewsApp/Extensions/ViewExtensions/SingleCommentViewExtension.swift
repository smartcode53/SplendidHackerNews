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
            
            Text(commentDate)
            
            Spacer()
            
            Image(systemName: "arrow.up.square.fill")
                .rotationEffect(Angle(degrees: !animateArrow ? 180 : 0))
        }
        .font(.headline.weight(.semibold))
        .foregroundColor(.orange)
        .padding(.bottom, 10)
        .onTapGesture {
            withAnimation(.easeInOut) {
                isExpanded.toggle()
            }
            
        }
    }
}
