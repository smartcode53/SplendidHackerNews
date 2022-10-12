//
//  ToastView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/12/22.
//

import SwiftUI

struct ToastView: View {
    
    let text: String
    
    var body: some View {
        VStack {
            Text(text)
                .foregroundStyle(.primary)
                .font(.subheadline.weight(.medium))
                .padding()
                .border(Color.black, width: 2)
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                
            
            Spacer()
        }
        
    }
}

struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        ToastView(text: "Stories Loaded Successfully")
    }
}
