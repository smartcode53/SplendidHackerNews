//
//  Logo.swift
//  HackerNewsApp
//
//  Created by Taha Broachwala on 11/1/22.
//

import Foundation
import SwiftUI

struct Logo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.97061*width, y: 0.09827*height))
        path.addLine(to: CGPoint(x: 0.80058*width, y: 0.09827*height))
        path.addLine(to: CGPoint(x: 0.80058*width, y: 0.89884*height))
        path.addCurve(to: CGPoint(x: 0.8009*width, y: 0.90174*height), control1: CGPoint(x: 0.80058*width, y: 0.89981*height), control2: CGPoint(x: 0.80097*width, y: 0.90077*height))
        path.addLine(to: CGPoint(x: 0.97061*width, y: 0.90174*height))
        path.addCurve(to: CGPoint(x: width, y: 0.87283*height), control1: CGPoint(x: 0.98658*width, y: 0.90174*height), control2: CGPoint(x: width, y: 0.88879*height))
        path.addLine(to: CGPoint(x: width, y: 0.12717*height))
        path.addCurve(to: CGPoint(x: 0.97061*width, y: 0.09827*height), control1: CGPoint(x: width, y: 0.11121*height), control2: CGPoint(x: 0.98658*width, y: 0.09827*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.36416*width, y: 0.09827*height))
        path.addLine(to: CGPoint(x: 0.36416*width, y: 0.90174*height))
        path.addLine(to: CGPoint(x: 0.3791*width, y: 0.90174*height))
        path.addLine(to: CGPoint(x: 0.59249*width, y: 0.90174*height))
        path.addLine(to: CGPoint(x: 0.59249*width, y: 0.79013*height))
        path.addCurve(to: CGPoint(x: 0.62009*width, y: 0.76012*height), control1: CGPoint(x: 0.59249*width, y: 0.77417*height), control2: CGPoint(x: 0.60413*width, y: 0.76012*height))
        path.addLine(to: CGPoint(x: 0.71387*width, y: 0.76012*height))
        path.addLine(to: CGPoint(x: 0.71387*width, y: 0.09827*height))
        path.addLine(to: CGPoint(x: 0.3791*width, y: 0.09827*height))
        path.addLine(to: CGPoint(x: 0.36416*width, y: 0.09827*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0, y: 0.12717*height))
        path.addLine(to: CGPoint(x: 0, y: 0.87283*height))
        path.addCurve(to: CGPoint(x: 0.02938*width, y: 0.90174*height), control1: CGPoint(x: 0, y: 0.88879*height), control2: CGPoint(x: 0.01342*width, y: 0.90174*height))
        path.addLine(to: CGPoint(x: 0.27746*width, y: 0.90174*height))
        path.addLine(to: CGPoint(x: 0.27746*width, y: 0.09827*height))
        path.addLine(to: CGPoint(x: 0.02938*width, y: 0.09827*height))
        path.addCurve(to: CGPoint(x: 0, y: 0.12717*height), control1: CGPoint(x: 0.01342*width, y: 0.09827*height), control2: CGPoint(x: 0, y: 0.11121*height))
        path.closeSubpath()
        return path
    }
}
