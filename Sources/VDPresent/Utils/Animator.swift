import UIKit

final class Animator: UIViewPropertyAnimator {

	#if VDPRESENT_LOG
	private let id = UUID().uuidString.prefix(4)
	#endif

	override func finishAnimation(at finalPosition: UIViewAnimatingPosition) {
		#if VDPRESENT_LOG
		print("[Animator:\(id)] finishAnimation(at: \(finalPosition == .end ? "end" : finalPosition == .start ? "start" : "current")) state=\(state)")
		#endif
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
		#if VDPRESENT_LOG
		print("[Animator:\(id)] continueAnimation factor=\(String(format: "%.3f", factor)) self.duration=\(String(format: "%.3f", self.duration)) requested=\(String(format: "%.3f", duration)) state=\(state) running=\(isRunning) reversed=\(isReversed)")
		#endif
		continueAnimation(
			withTimingParameters: parameters,
			durationFactor: factor
		)
	}

	deinit {
		#if VDPRESENT_LOG
		print("[Animator:\(id)] deinit state=\(state)")
		#endif
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
extension UIViewAnimatingState: @retroactive CustomStringConvertible {
	public var description: String {
		switch self {
		case .inactive: return "inactive"
		case .active: return "active"
		case .stopped: return "stopped"
		@unknown default: return "unknown(\(rawValue))"
		}
	}
}
#endif
