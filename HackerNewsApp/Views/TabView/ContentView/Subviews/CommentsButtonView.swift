//
//  CommentsButtonView.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 9/23/22.
//

import SwiftUI

struct CommentsButtonView<T>: View where T: CommentsButtonProtocol, T: SafariViewLoader {
    
    @ObservedObject var vm: T
    var action: (() -> Void)? = nil
    
    var body: some View {
        if let commentCount =  vm.story?.descendants {
            let displayCount = Self.formatCount(commentCount)
            if let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text(displayCount)
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text(displayCount)
                }
            }
        }
    }

    private static func formatCount(_ count: Int) -> String {
        switch count {
        case 0..<1000:
            return String(count)
        case 1000..<1_000_000:
            let value = Double(count) / 1000
            return value >= 10 ? "\(Int(value))k" : String(format: "%.1fk", value)
        case 1_000_000..<1_000_000_000:
            let value = Double(count) / 1_000_000
            return value >= 10 ? "\(Int(value))m" : String(format: "%.1fm", value)
        default:
            let value = Double(count) / 1_000_000_000
            return value >= 10 ? "\(Int(value))b" : String(format: "%.1fb", value)
        }
    }
}
