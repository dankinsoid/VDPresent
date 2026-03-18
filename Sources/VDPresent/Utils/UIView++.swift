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
}
