//
//  ImagePlaceholderView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/11/22.
//

import SwiftUI

struct ImagePlaceholderView: View {
    
    let height: CGFloat
    let width: CGFloat
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(colors: [.orange, .indigo], startPoint: .top, endPoint: .bottom)
                .frame(width: width, height: height)
//                .frame(height: height)
                .blur(radius: 60)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)

            Text("HN")
                .fontWeight(.bold)
                .font(.title3)
                .foregroundColor(.secondary)
                .padding()
                .rotation3DEffect(Angle(degrees: -15), axis: (x: 0, y: 1, z: 0))
        }
    }
}

struct ImagePlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        ImagePlaceholderView(height: 300, width: 300)
    }
}
