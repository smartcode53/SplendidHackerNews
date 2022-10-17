//
//  StorySelectionView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/14/22.
//

import SwiftUI

struct StorySelectionView: View {
    
    @Binding var selectedStoryType: StoryType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { reader in
                HStack(spacing: 0) {
                    ForEach(StoryType.allCases, id: \.rawValue) { type in
                        Text(type.rawValue)
                            .padding(10)
                            .background(selectedStoryType == type ? Color("NavigationBarColor") : Color("NavigationBarColor").opacity(0.3))
                            .foregroundColor(.white)
                            .font(.headline.weight(.bold))
                            .cornerRadius(12)
                            .padding(.vertical)
                            .padding(.horizontal, 10)
                            .id(selectedStoryType)
                            .onTapGesture {
                                selectedStoryType = type
                                withAnimation(.spring()) {
                                    reader.scrollTo(selectedStoryType.rawValue, anchor: .leading)
                                }
                            }
                    }
                }
            }
        }
        .background(.clear)
    }
}

struct StorySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        StorySelectionView(selectedStoryType: .constant(.topstories))
    }
}
