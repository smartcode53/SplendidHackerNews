import UIKit

final class ShimmerLayer: CAGradientLayer {
    private let animationKey = "shimmerSlide"

    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func commonInit() {
        startPoint = CGPoint(x: 0, y: 0.5)
        endPoint = CGPoint(x: 1, y: 0.5)
        let base = UIColor.tertiarySystemFill.cgColor
        let highlight = UIColor.quaternarySystemFill.cgColor
        colors = [base, highlight, base]
        locations = [0, 0.5, 1]
    }

    func startAnimating() {
        guard animation(forKey: animationKey) == nil else { return }
        let anim = CABasicAnimation(keyPath: "locations")
        anim.fromValue = [-1.0, -0.5, 0.0]
        anim.toValue = [1.0, 1.5, 2.0]
        anim.duration = 1.2
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        add(anim, forKey: animationKey)
    }

    func stopAnimating() {
        removeAnimation(forKey: animationKey)
    }
}
