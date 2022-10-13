//
//  IntExtension.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 10/14/22.
//

import Foundation
import SwiftUI

extension Int {
    var compressedNumber: String {
        if self > 999 {
            if self < 10_000 {
                let stringArr = String(self).split(separator: "")
                let firstDig = stringArr[0]
                let secondDig = stringArr[1]
                return firstDig + "." + secondDig + "k"
            } else if self > 9999 {
                let stringArr = String(self).split(separator: "")
                let firstTwoDigits = stringArr[0] + stringArr[1]
                return firstTwoDigits + "k"
            }
        }
        
        return String(self)
    }
}
