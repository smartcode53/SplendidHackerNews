//
//  ToastView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/12/22.
//

import SwiftUI

struct ToastView: View {
    
    let text: String
    let textColor: Color
    
    var body: some View {
        VStack {
            HStack {
                Text(text)
                    .foregroundStyle(textColor)
                    .font(.subheadline.weight(.semibold))
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.trailing)
            }   
            
            Spacer()
        }
        
    }
}
struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        ToastView(text: "Stories Loaded Successfully", textColor: .primary)
    }
}
