//
//  FontExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/31/22.
//

import Foundation
import SwiftUI

extension Font {
    public static func system(size: CGFloat, weight: UIFont.Weight, width: UIFont.Width) -> Font {
        Font(UIFont.systemFont(ofSize: size, weight: weight, width: width))
    }
}
