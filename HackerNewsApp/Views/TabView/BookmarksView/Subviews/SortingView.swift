//
//  SortingView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 11/2/22.
//

import SwiftUI

struct SortingView: View {
    
    @EnvironmentObject var globalSettings: GlobalSettingsViewModel
    @Namespace var namespace
    @State private var shouldExpand: Bool = false
    
    var body: some View {
        VStack {
            if shouldExpand {
                expandedView
            } else {
                contractedView
            }
            
            
        }
        
    }
}

extension SortingView {
    
    private var contractedView: some View {
        HStack {
            Spacer()
            
            HStack {
                Text("Sort By:")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .matchedGeometryEffect(id: "title", in: namespace)
                
                Text("\(globalSettings.selectedSortType.rawValue)")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white)
                    .contentShape(Rectangle())
                    .matchedGeometryEffect(id: "titleValue", in: namespace)
                    
            }
            
            
            Spacer()
            
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundColor(.white)
                .font(.headline)
                .matchedGeometryEffect(id: "icon", in: namespace)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .matchedGeometryEffect(id: "rectangle", in: namespace)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring()) {
                shouldExpand = true
            }
        }
    }
    
    private var expandedView: some View {
        VStack {
            HStack {
                Text("Sort By")
                    .foregroundColor(.white)
                    .font(.title3.weight(.bold))
                    .matchedGeometryEffect(id: "title", in: namespace)
                
                Spacer()
                
                Image(systemName: "xmark")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .matchedGeometryEffect(id: "icon", in: namespace)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring()) {
                    shouldExpand = false
                }
            }
            
            VStack {
                ForEach(SortType.allCases, id: \.self) { type in
                    
                    if globalSettings.selectedSortType == type {
                        Text(type.rawValue)
                            .foregroundColor(.black)
                            .font(.headline.weight(.semibold))
                            .contentShape(Rectangle())
                            .matchedGeometryEffect(id: "titleValue", in: namespace)
                            .frame(width: 100)
                            .padding()
                            .background(.white) // Change this to affect globalSettings
                            .cornerRadius(8)
                            .padding(.vertical, 10)
                    } else {
                        Text(type.rawValue)
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding()
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    globalSettings.selectedSortType = type
                                    shouldExpand = false
                                }
                            }
                        
                    }
                    
                    
                        
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .matchedGeometryEffect(id: "rectangle", in: namespace)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        
    }
    
}

struct SortingView_Previews: PreviewProvider {
    static var previews: some View {
        SortingView()
    }
}
