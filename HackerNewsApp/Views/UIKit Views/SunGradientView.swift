import UIKit

final class SunGradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setupGradient()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
            view.updateColors()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupGradient() {
        gradientLayer.type = .radial
        gradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: -0.2, y: 1.2)
        updateColors()
    }

    private func updateColors() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        let orange = UIColor.systemOrange
        gradientLayer.colors = [
            orange.withAlphaComponent(isDark ? 0.45 : 0.38).cgColor,
            orange.withAlphaComponent(isDark ? 0.22 : 0.18).cgColor,
            orange.withAlphaComponent(isDark ? 0.08 : 0.06).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.25, 0.55, 1.0]
    }
}
