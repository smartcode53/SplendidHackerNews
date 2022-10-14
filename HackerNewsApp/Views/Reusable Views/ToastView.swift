//
//  ToastView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/12/22.
//

import SwiftUI

struct ToastView<Content: View>: View {
    
    let text: String
    let content: Content
    
    var body: some View {
        VStack {
            HStack {
                Text(text)
                    .foregroundStyle(.primary)
                    .font(.subheadline.weight(.medium))
                    .padding()
                    .border(Color.black, width: 2)
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .padding(.trailing)
                
                content
            }   
            
            Spacer()
        }
        
    }
}

extension ToastView {
    init(text: String, @ViewBuilder content: () -> Content) {
        self.text = text
        self.content = content()
    }
}

struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        ToastView(text: "Stories Loaded Successfully") {
            Text("Something")
        }
    }
}
