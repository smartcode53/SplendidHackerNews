//
//  CustomNavBarView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/15/22.
//

import SwiftUI

struct CustomNavBarView: View {
    
    @Environment(\.dismiss) var dismiss
    
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
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
        }
    }
    
    private var gradientLogo: some View {
        
        Text("HN")
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(LinearGradient(colors: [.orange, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .rotation3DEffect(Angle(degrees: -15), axis: (x: 0, y: 1, z: 0))
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
