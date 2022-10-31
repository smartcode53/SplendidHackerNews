//
//  CustomNavBarView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/15/22.
//

import SwiftUI

struct CustomNavBarView: View {
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let showBackButton: Bool
    let title: String
    
    var body: some View {
        
        ZStack {
            
            Color("NavigationBarColor").ignoresSafeArea()
            
            HStack {
                
                if showBackButton {
                    backButton
                }
                
                gradientLogo
                    .padding(.trailing, 10)
                
                titleSection
                
                Spacer()
                
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 80)
        .tint(.white)
        .font(.headline)
    }
}


extension CustomNavBarView {
    
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.backward")
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 4) {
            Text(title)
//                .font(.title2.weight(.bold))
                .font(.system(size: 22, weight: .bold, width: .expanded))
                .foregroundColor(.primary)
        }
    }
    
    private var gradientLogo: some View {
        
        Text("HN")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
//            .rotation3DEffect(Angle(degrees: -25), axis: (x: 0, y: 1, z: 0))
            .kerning(-3)
    }
}

struct Logo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.00124*width, y: 0.29539*height))
        path.addLine(to: CGPoint(x: 0.00124*width, y: 0.81605*height))
        path.addLine(to: CGPoint(x: 0.99876*width, y: 0.99857*height))
        path.addLine(to: CGPoint(x: 0.99876*width, y: 0.00143*height))
        path.addLine(to: CGPoint(x: 0.00124*width, y: 0.29539*height))
        path.closeSubpath()
        return path
    }
}

struct CustomNavBarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CustomNavBarView(showBackButton: true, title: "Top Stories")
            Spacer()
        }
        
    }
}
