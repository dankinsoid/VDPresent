import UIKit

extension UIView {
	
	func safeArea(in parent: UIView?) -> UIEdgeInsets {
		guard let parent = parent ?? window else { return .zero }
		guard parent.safeAreaInsets != .zero else { return .zero }
		let frameInParent = convert(bounds, to: parent)
		let top = max(0, parent.safeAreaInsets.top - frameInParent.minY)
		let left = max(0, parent.safeAreaInsets.left - frameInParent.minX)
		let bottom = max(0, frameInParent.maxY - (parent.bounds.height - parent.safeAreaInsets.bottom))
		let right = max(0, frameInParent.maxX - (parent.bounds.width - parent.safeAreaInsets.right))
		return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
	}

	/// Frame in window coordinates ignoring the view's own transform.
	/// Uses `bounds.size` (unaffected by transform) and `center` (= layer.position,
	/// stored in superview coordinates independently of transform).
	/// @ai-generated(solo)
	var untransformedFrameInWindow: CGRect {
		let size = bounds.size
		let globalCenter = superview?.convert(center, to: nil) ?? center
		return CGRect(
			x: globalCenter.x - size.width / 2,
			y: globalCenter.y - size.height / 2,
			width: size.width,
			height: size.height
		)
	}
}
