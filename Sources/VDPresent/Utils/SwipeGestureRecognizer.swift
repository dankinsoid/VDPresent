import SwiftUI
import VDTransition

final class SwipeGestureRecognizer: UIPanGestureRecognizer, UIGestureRecognizerDelegate {

	var startFromEdges = false
	var edges: NSDirectionalRectEdge = []
	var shouldStart: (Edge) -> Bool = { _ in true }
	var update: (UIPresentation.Interactivity.State, Edge) -> UIPresentation.Interactivity.Policy = { _, _ in .prevent }
	/// Called during overscroll (negative progress — dragging past the starting
	/// position, away from the dismiss edge). Receives raw distance in points
	/// (always `>= 0`) and the pre-computed `limit` in points — the maximum
	/// amount the view may extend along the overscroll axis before it would
	/// collide with the window's safe area. The handler is expected to apply
	/// a transform directly to the target view, using `limit` as the asymptote
	/// of any rubber-band curve. See `SwipeConfiguration.overscroll`.
	var overscroll: ((Edge, CGFloat, CGFloat) -> Void)?
	var direction: TransitionDirection = .removal
	var fullDuration: Double = UIKitAnimation.defaultDuration
	weak var target: UIView?

	private var edge: Edge?
	private var axis: NSLayoutConstraint.Axis {
		switch edge {
		case .leading, .trailing: return .horizontal
		default: return .vertical
		}
	}

	private var wasBegun = false
	private var lastPercent: CGFloat?
	private var initialPercent: CGFloat = 0
	/// Non-nil while the pan is in overscroll mode: the active transition has
	/// been torn down and the view is being stretched by the `overscroll`
	/// handler. Holds the edge that was active when overscroll started, so
	/// subsequent `.changed` / `.ended` ticks use a stable direction.
	///
	/// If the user drags back into the positive range, overscroll is cleared
	/// and a fresh transition is started via `begin()`.
	private var overscrollEdge: Edge?
	/// Maximum stretch distance (in points) allowed along the overscroll axis
	/// before the view would reach the window's safe area. Computed *once* at
	/// the moment overscroll is entered (in `.began` or in the in-gesture
	/// transition-to-overscroll branch of `.changed`) and reused for every
	/// subsequent tick until the gesture ends. Computing this per-frame would
	/// be wrong: as the view stretches, its `frame` crosses into the safe
	/// area, UIKit recalculates `safeAreaInsets`, and the limit would drift
	/// under the user's finger.
	private var overscrollLimit: CGFloat = 0

	init() {
		super.init(target: nil, action: nil)
		delegate = self
		addTarget(self, action: #selector(handle))
		delaysTouchesBegan = false
		delaysTouchesEnded = false
	}

	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
		guard let target, let view = touch.view else { return false }
		return view.isDescendant(of: target) && target.bounds.contains(touch.location(in: target))
	}

	@objc
	private func handle(_ gestureRecognizer: UIPanGestureRecognizer) {
		switch gestureRecognizer.state {
		case .possible:
			break

		case .began:
			guard !wasBegun else {
				return
			}
			// Ensure a stale edge from a previous gesture doesn't leak into
			// this one (e.g. previous gesture ended in overscroll without a
			// full `stop()`).
			edge = nil
			let initialEdge = computeEdge()
			// If the drag starts away from any configured dismiss edge and
			// overscroll is configured for that opposite edge, enter overscroll
			// mode directly without building a transition.
			if
				overscroll != nil,
				!edges.contains(NSDirectionalRectEdge(initialEdge)),
				edges.contains(NSDirectionalRectEdge(initialEdge.opposite))
			{
				let oEdge = initialEdge.opposite
				overscrollEdge = oEdge
				// Pure overscroll: the view's transform is identity (no
				// active transition), so the limit can be measured directly
				// from its current window-space frame.
				overscrollLimit = computeOverscrollLimit(for: oEdge)
				// No `begin()` — no transition, no animator. The `.changed`
				// handler will route ticks through `applyOverscroll`.
			} else {
				begin()
			}

		case .changed:
			// Already in overscroll: either keep stretching, or (if the user
			// pulled back into the positive range) snap back and start a
			// fresh transition.
			if let oEdge = overscrollEdge {
				let rawPercent = percent
				if rawPercent < 0 {
					applyOverscroll(edge: oEdge, rawPercent: rawPercent)
				} else {
					resetOverscrollImmediately()
					// Re-arm the gesture as if it just began — a new transition
					// is built from scratch. Clear the cached edge so
					// `begin()` recomputes it from current velocity (which is
					// now heading toward the dismiss edge).
					edge = nil
					begin()
					let clamped = min(1, max(0, rawPercent))
					if wasBegun { update(percent: clamped) }
				}
				return
			}

			guard wasBegun else { return }
			// If the user drags past the origin and there's an opposite-edge
			// dismiss configured, flip the gesture to that edge instead of
			// treating it as overscroll.
			if
				let edge,
				!startFromEdges,
				edges.contains(NSDirectionalRectEdge(edge.opposite)),
				shouldStart(edge.opposite),
				percent < 0
			{
				finish(completed: false, immediately: true)
				self.edge = edge.opposite
				begin()
			}
			let rawPercent = percent
			if rawPercent < 0, overscroll != nil, let edge {
				// Entering overscroll: fully tear down the active transition
				// (animator removed, view settled), remember the edge, then
				// apply the first overscroll tick.
				let enterEdge = edge
				finish(completed: false, immediately: true)
				overscrollEdge = enterEdge
				// After `finish(immediately: true)` the interactive transition
				// has been torn down synchronously and the view is back at its
				// identity-transform baseline — safe to measure the limit now.
				overscrollLimit = computeOverscrollLimit(for: enterEdge)
				applyOverscroll(edge: enterEdge, rawPercent: rawPercent)
			} else {
				let clamped = min(1, max(0, rawPercent))
				update(percent: clamped)
			}

		case .ended:
			let p = percent
			let v = velocityInDirection
			if overscrollEdge != nil {
				animateOverscrollReturn()
				overscrollEdge = nil
				stop()
				return
			}
			guard wasBegun else {
				return
			}
			let completed = p > 0.35 || v > 800
			finish(completed: completed)

		case .failed, .cancelled:
			if overscrollEdge != nil {
				animateOverscrollReturn()
				overscrollEdge = nil
				stop()
				return
			}
			guard wasBegun else { return }
			finish(completed: false)

		@unknown default:
			break
		}
	}

	private func begin() {
		setAxisIfNeeded()
		let policy = update(.begin, edge ?? .leading)
		if policy == .allow {
			wasBegun = true
		} else {
			stop()
		}
	}

	private func update(percent: Double) {
		guard percent != lastPercent else { return }
		lastPercent = percent
		if update(.change(direction.at(percent)), edge ?? .leading) == .prevent {
			stop()
		}
	}

	private func finish(completed: Bool, immediately: Bool = false) {
		_ = update(.end(completed: completed, after: immediately ? 0 : fullDuration), edge ?? .leading)
		stop()
	}

	private func stop() {
		wasBegun = false
		lastPercent = nil
		edge = nil
		overscrollLimit = 0
	}

	/// Applies one tick of the overscroll handler for the given raw percent
	/// (`< 0`). Converts percent back to raw distance in points and routes
	/// through the configured `overscroll` closure together with the
	/// pre-computed `overscrollLimit`.
	private func applyOverscroll(edge: Edge, rawPercent: CGFloat) {
		guard let overscroll else { return }
		let dimension: CGFloat
		switch edge {
		case .leading, .trailing: dimension = target?.frame.width ?? 0
		case .top, .bottom:       dimension = target?.frame.height ?? 0
		}
		let distance = -rawPercent * dimension
		overscroll(edge, distance, overscrollLimit)
	}

	/// Computes the maximum stretch distance allowed along the given edge
	/// before the view would collide with the window's safe area.
	///
	/// Called from the two points where the recognizer transitions into
	/// overscroll mode:
	///   - `.began` pure-overscroll branch (drag started away from a
	///     dismiss edge),
	///   - `.changed` transition-to-overscroll branch (drag crossed origin
	///     during an active interactive transition; `finish(immediately:)`
	///     has just settled the view back to its pre-transition state).
	///
	/// At both points the target's transform is `.identity`, so `convert`
	/// returns the geometric frame in window coordinates. We then measure
	/// the free space between that frame and the window's safe area on the
	/// side *opposite* the drag direction (the side the view will extend
	/// toward during stretch).
	///
	/// Returns `0` if the view has no window, or if the view is already
	/// flush with (or past) the safe area on the relevant side: in that
	/// case the overscroll handler should produce no visible stretch, which
	/// is exactly the "native pageSheet hits the ceiling" feel.
	///
	/// A small cushion (`margin`) is subtracted so the visible edge of the
	/// stretched view never quite reaches the system safe area, avoiding the
	/// `safeAreaInsets` recalculation that triggers when a subview crosses
	/// into the inset region.
	private func computeOverscrollLimit(for edge: Edge) -> CGFloat {
		guard let target, let window = target.window else { return 0 }
		// Small cushion: crossing the safe area "a tiny bit" is acceptable
		// (some users expect the stretch to kiss the notch), fully crossing
		// is not — it triggers `safeAreaInsets` recalc on the sheet's
		// subviews and causes visible jitter.
		let margin: CGFloat = 4
		let frameInWindow = target.convert(target.bounds, to: window)
		let safeTop    = window.safeAreaInsets.top
		let safeBottom = window.bounds.height - window.safeAreaInsets.bottom
		let safeLeft   = window.safeAreaInsets.left
		let safeRight  = window.bounds.width - window.safeAreaInsets.right
		let gap: CGFloat
		switch edge {
		// Dragging toward `.bottom` grows the view *upward*, so the relevant
		// free space is from the view's current top edge to the safe-area
		// top line.
		case .bottom: gap = frameInWindow.minY - safeTop
		case .top:    gap = safeBottom - frameInWindow.maxY
		case .leading:  gap = safeRight - frameInWindow.maxX
		case .trailing: gap = frameInWindow.minX - safeLeft
		}
		return max(0, gap - margin)
	}

	/// Snaps the target view's transform back to identity without animation.
	/// Used when the user drags back from overscroll into the normal progress
	/// range mid-gesture — we need a clean identity state before starting a
	/// fresh transition.
	private func resetOverscrollImmediately() {
		target?.transform = .identity
		overscrollEdge = nil
		overscrollLimit = 0
	}

	/// Animates the target view's transform back to identity with an
	/// ease-out curve. Called when the gesture ends while still in overscroll.
	///
	/// Duration scales with how far the view was actually stretched: a
	/// tiny nudge returns almost instantly, a near-max stretch takes
	/// (close to) the full transition duration. Measured from the
	/// current transform's translation component — works for both
	/// `.stretch` (tx/ty ≈ stretch/2) and `.offset` (tx/ty = shift),
	/// because we only care about *relative* progress.
	///
	/// TODO edge cases:
	///   - If the view is removed (programmatic dismiss) while this animation
	///     runs, the transform is simply discarded along with the view.
	///   - If a new gesture begins before this animation finishes, the new
	///     gesture's baseline will be the in-flight transform rather than
	///     identity.
	private func animateOverscrollReturn() {
		guard let target else { return }
		let t = target.transform
		let translation = max(abs(t.tx), abs(t.ty))
		let progress = overscrollLimit > 0
			? min(1, translation / overscrollLimit)
			: 0
		// Minimum so micro-returns don't snap instantly (looks abrupt);
		// scale by `fullDuration` so the feel matches the rest of the
		// presentation's motion without copying its full length.
		let minDuration: TimeInterval = 0.08
		let duration = max(minDuration, fullDuration * TimeInterval(progress))
		UIView.animate(
			withDuration: duration,
			delay: 0,
			options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
		) {
			target.transform = .identity
		}
	}

	private var percent: CGFloat {
		guard let target else { return 0 }
		setAxisIfNeeded()
		switch axis {
		case .vertical:
			guard target.frame.height > 0 else { return 1 }
			return offset / target.frame.height
		case .horizontal:
			guard target.frame.width > 0 else { return 1 }
			return offset / target.frame.width
		@unknown default:
			return initialPercent
		}
	}

	private var offset: CGFloat {
		guard let view else { return 0 }
		var value: CGFloat
		let offset = translation(in: view)
		setAxisIfNeeded()
		switch axis {
		case .vertical:
			guard edges.contains(.top) || edges.contains(.bottom) else { return 0 }
			value = -offset.y
			if edges.contains(.bottom), edges.contains(.top) {
				value = abs(value)
			} else if edges.contains(.bottom) {
				value = -value
			}
			return value + initialPercent * (target?.frame.height ?? 0)

		case .horizontal:
			guard edges.contains(.leading) || edges.contains(.trailing) else { return 0 }
			value = -offset.x
			if edges.contains(.trailing), edges.contains(.leading) {
				value = abs(value)
			} else if edges.contains(.trailing) {
				value = -value
			}
			return value + initialPercent * (target?.frame.width ?? 0)

		@unknown default:
			return 0
		}
	}

	private var velocityInDirection: CGFloat {
		let vector = velocity(in: view)
		let isLtr = view?.effectiveUserInterfaceLayoutDirection != .rightToLeft
		switch edge {
		case .top:
			return -vector.y
		case .bottom:
			return vector.y
		case .trailing:
			return isLtr ? vector.x : -vector.x
		default:
			return isLtr ? -vector.x : vector.x
		}
	}

	private func setAxisIfNeeded() {
		guard edge == nil else { return }
		edge = computeEdge()
	}

	private func computeEdge() -> Edge {
		let offset = velocity(in: view)
		let isLtr = view?.effectiveUserInterfaceLayoutDirection != .rightToLeft
		let leftEdge: Edge = isLtr ? .leading : .trailing
		let rightEdge: Edge = isLtr ? .trailing : .leading
		return abs(offset.x) < abs(offset.y)
			? offset.y < 0 ? .top : .bottom
			: offset.x < 0 ? leftEdge : rightEdge
	}

	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		let edge = computeEdge()
		guard
			let view,
			let target,
			target.bounds.contains(gestureRecognizer.location(in: target))
		else {
			return false
		}
		// Normal case: drag is heading toward a configured dismiss edge.
		let isDismissDirection = edges.contains(NSDirectionalRectEdge(edge)) && shouldStart(edge)
		// Overscroll-only case: drag is heading *away* from a dismiss edge
		// (i.e. toward the opposite edge) and overscroll is configured. We
		// still start the gesture so overscroll can take over immediately.
		let isOverscrollDirection = overscroll != nil
			&& edges.contains(NSDirectionalRectEdge(edge.opposite))
		guard isDismissDirection || isOverscrollDirection else {
			return false
		}
		let threshold: CGFloat = 36
		guard startFromEdges else {
			return true
		}
		let size = view.frame.size
		let location = gestureRecognizer.location(in: view)

		let edgeInsets = view.nsDirectionalEdgeInsets(
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
		return result
	}
}
