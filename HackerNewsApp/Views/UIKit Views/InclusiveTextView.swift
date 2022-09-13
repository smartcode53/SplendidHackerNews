//
//  InclusiveTextView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/12/22.
//

import Foundation
import UIKit
import SwiftUI

struct InclusiveTextView: UIViewRepresentable {
    
    let text: String
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.text = text.parsedText
        view.automaticallyAdjustsScrollIndicatorInsets = false
        view.linkTextAttributes = [.foregroundColor: UIColor.systemOrange]
        view.isSelectable = true
        view.isEditable = false
        view.isUserInteractionEnabled = true
        view.dataDetectorTypes = .link
        return view
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = self.text.parsedText
    }
    
}
