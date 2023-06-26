import UIKit

final class Animator: UIViewPropertyAnimator {

	override func finishAnimation(at finalPosition: UIViewAnimatingPosition) {
		guard state != .inactive else { return }
		if state != .stopped {
			stopAnimation(false)
		}
		if state == .stopped {
			super.finishAnimation(at: finalPosition)
		} else if let value = finalPosition.complete {
			fractionComplete = value
		}
	}

	deinit {
		finishAnimation(at: .current)
	}
}

private extension UIViewAnimatingPosition {

	var complete: CGFloat? {
		switch self {
		case .end: return 1
		case .start: return 0
		default: return nil
		}
	}
}
