import UIKit

extension SwipeView {

	final class Instance {

		var delegate: SwipeViewDelegate?

		let edges: NSDirectionalRectEdge
		let startFromEdges: Bool
		private var wasBegan = false
		private var lastPercent: CGFloat?
		private let threshold: CGFloat = 36
		var observers: [(CGFloat) -> Void] = []
		unowned var scroll: SwipeView

		private var percent: CGFloat {
			let dif = scroll.contentOffset - scroll.initialOffset
			if dif.x == 0 {
				return offset / scroll.frame.height
			} else {
				return offset / scroll.frame.width
			}
		}

		private var offset: CGFloat {
			var value: CGFloat
			let offset = scroll.contentOffset - scroll.initialOffset
			if offset.x == 0 {
				guard edges.contains(.top) || edges.contains(.bottom) else { return 0 }
				value = offset.y
				if edges.contains(.bottom), edges.contains(.top) {
					value = abs(value)
				} else if edges.contains(.bottom) {
					value = -value
				}
				return value
			} else {
				guard edges.contains(.leading) || edges.contains(.trailing) else { return 0 }
				value = offset.x
				if edges.contains(.trailing), edges.contains(.leading) {
					value = abs(value)
				} else if edges.contains(.trailing) {
					value = -value
				}
				return value
			}
		}

		init(scroll: SwipeView, key: Key) {
			self.scroll = scroll
			edges = key.edge
			startFromEdges = key.startFromEdges
		}

		func didScroll() {
			guard scroll.frame.width > 0, delegate?.wasBegun == true else { return }
			let percent = abs(max(0, min(1, percent)))
			defer { notify() }
			guard percent != lastPercent else { return }
			lastPercent = percent
			delegate?.update(percent)
		}

		func didEndDecelerating() {
			guard delegate?.wasBegun == true else { return }
			let percent = percent
			lastPercent = percent
			if percent >= 1 {
				delegate?.finish()
				lastPercent = nil
			} else if percent <= 0 {
				delegate?.cancel()
				lastPercent = nil
			}
		}

		func willBeginDragging() {
			guard delegate?.wasBegun == false else { return }
			delegate?.begin()
		}

		func shouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
			guard startFromEdges else {
				return delegate?.shouldBegin() ?? true
			}
			let size = gestureRecognizer.view?.frame.size ?? scroll.frame.size
			let location = gestureRecognizer.location(in: gestureRecognizer.view ?? scroll)

			let edgeInsets = scroll.nsDirectionalEdgeInsets(
				top: abs(location.y),
				left: abs(location.x),
				bottom: abs(size.height - location.y),
				right: abs(size.width - location.x)
			)

			let result = (
				edges.contains(.trailing) && edgeInsets.leading < threshold ||
					edges.contains(.leading) && edgeInsets.trailing < threshold ||
					edges.contains(.top) && edgeInsets.bottom < threshold ||
					edges.contains(.bottom) && edgeInsets.top < threshold
			)
			return result && (delegate?.shouldBegin() ?? true)
		}

		private func notify() {
			guard !observers.isEmpty else { return }
			let offset = offset
			observers.forEach {
				$0(offset)
			}
		}
	}

	struct Key: Hashable {

		let edge: NSDirectionalRectEdge
		let startFromEdges: Bool

		func hash(into hasher: inout Hasher) {
			edge.rawValue.hash(into: &hasher)
			startFromEdges.hash(into: &hasher)
		}
	}
}
