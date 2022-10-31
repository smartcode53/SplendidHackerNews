//
//  DragToRefreshView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/25/22.
//

import SwiftUI

struct DragToRefreshView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @State private var position: CGPoint = .init(x: 25, y: 275)
    @State private var isDragging: Bool = false
    
    let refreshFunc: () -> Void
    
    var body: some View {
        ZStack {
            if !isDragging {
                chevronView
                    .position(x: 25, y: 220)
            }
            
            
            
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                    .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: -10)
                
                Image(systemName: "arrow.clockwise")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            .position(position)
            .gesture(gesture)
            
        }
        .frame(width: 50, height: 300)
        .background(.regularMaterial.opacity(isDragging ? 1 : 0))
        .clipShape(Capsule())
    }
}


extension DragToRefreshView {
    
    var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                
                if value.location.y <= 275 && value.location.y >= 25 {
                    withAnimation(.spring(response: 0.2)) {
                        position.y = value.location.y
                        isDragging = true
                    }
                    
                    
                    
                    if position.y < 50 {
                        refreshFunc()
                    }
                }
            }
            .onEnded { value in
                withAnimation(.spring()) {
                    position = .init(x: 25, y: 275)
                    isDragging = false
                }
            }
    }
    
    var chevronView: some View {
        VStack() {
            ForEach(0..<3) { _ in
                Image(systemName: "chevron.up")
                    .foregroundColor(colorScheme == .light ? .black.opacity(0.3) : .white.opacity(0.5))
            }
        }
    }
    
}

struct DragToRefreshView_Previews: PreviewProvider {
    
    static var previews: some View {
        DragToRefreshView(refreshFunc: {})
    }
}
