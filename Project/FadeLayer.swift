import UIKit

final class FadeLayer: CALayer {

	@NSManaged var percent: CGFloat
	weak var bottomView: UIView?
	weak var topView: UIView?

	override class func needsDisplay(forKey key: String) -> Bool {
		if key == (\FadeLayer.percent)._kvcKeyPathString {
			return true
		}
		return CALayer.needsDisplay(forKey: key)
	}

	override func draw(in ctx: CGContext) {
		super.draw(in: ctx)
		setProgress(model: model())
	}

	func drawPath() {
		setProgress(model: self)
	}

	override func needsDisplay() -> Bool {
		let result = super.needsDisplay()
		if result {
			setProgress(model: self)
		}
		return result
	}

	override func animation(forKey key: String) -> CAAnimation? {
		if key == (\FadeLayer.percent)._kvcKeyPathString {
			let animation = (
				super.animation(forKey: (\FadeLayer.backgroundColor)._kvcKeyPathString ?? "backgroundColor") as? CABasicAnimation
			) ?? CABasicAnimation(keyPath: key)
			animation.keyPath = key
			return animation
		}
		return super.animation(forKey: key)
	}

	private func setProgress(model: FadeLayer) {}
}

extension UIView {

	var subviewsByLevels: [[UIView]] {
		[]
	}
}

class FView: UIView {

	let rect = UIView()

	init() {
		super.init(frame: .zero)
		addSubview(rect)
		rect.backgroundColor = .black
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		rect.frame = CGRect(x: 100, y: 250, width: 100, height: 200)
	}
}
