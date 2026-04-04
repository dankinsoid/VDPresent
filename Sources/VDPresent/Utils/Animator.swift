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

	func continueAnimation(withTimingParameters parameters: UITimingCurveProvider? = nil, duration: Double) {
		let factor = self.duration < 0.001 ? 1 : duration / self.duration
		continueAnimation(
			withTimingParameters: parameters,
			durationFactor: factor
		)
	}

	deinit {
		finishAnimation(at: .end)
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

#if VDPRESENT_LOG
extension UIViewAnimatingState {
	var descr: String {
		switch self {
		case .inactive: return "inactive"
		case .active: return "active"
		case .stopped: return "stopped"
		@unknown default: return "unknown(\(rawValue))"
		}
	}
}
#endif
