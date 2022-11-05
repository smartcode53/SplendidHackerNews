//
//  StorySelectionView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/14/22.
//

import SwiftUI

struct StorySelectionView: View {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    @Binding var selectedStoryType: StoryType
    
    var body: some View {
        
        if horizontalSizeClass == .compact {
            smallStorySelectionView
        } else if horizontalSizeClass == .regular {
            largeStorySelectionView
        }
    }
}

extension StorySelectionView {
    
    var smallStorySelectionView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { reader in
                HStack(spacing: 0) {
                    ForEach(StoryType.allCases, id: \.rawValue) { type in
                        Text(type.rawValue)
                            .padding(10)
                            .foregroundStyle(selectedStoryType == type ? LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.primary, .primary], startPoint: .top, endPoint: .bottom))
                            .font(.title3.weight(.bold))
                            .padding(.vertical, 5)
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
    }
    
    var largeStorySelectionView: some View {
            HStack(alignment: .center, spacing: 0) {
                Spacer()
                ForEach(StoryType.allCases, id: \.rawValue) { type in
                    Text(type.rawValue)
                        .padding(10)
                        .foregroundStyle(selectedStoryType == type ? LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.primary, .primary], startPoint: .top, endPoint: .bottom))
                        .font(.title3.weight(.bold))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .id(selectedStoryType)
                        .onTapGesture {
                            selectedStoryType = type
                        }
                }
                Spacer()
            }
    }
    
}

struct StorySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        StorySelectionView(selectedStoryType: .constant(.topstories))
    }
}
