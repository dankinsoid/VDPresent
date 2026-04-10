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

	/// The scroll view that the current touch sequence is interacting
	/// with. Discovered automatically via `shouldRecognizeSimultaneouslyWith`:
	/// UIKit only invokes that delegate method for gestures whose hit-test
	/// regions overlap, so any `UIPanGestureRecognizer` attached to a
	/// `UIScrollView` inside our target view that UIKit offers there is,
	/// by definition, the scroll view under the user's finger. We accept
	/// it (and cache it) only if the scroll view still has room to scroll
	/// *away from* the dismiss edge — otherwise there is nothing to hand
	/// off from, and the normal swipe-dismiss flow is the right behavior.
	///
	/// Cleared in `stop()` and in the observing-end branches. `nil` means
	/// the touch did not land inside a cooperating scroll view (e.g. on a
	/// grabber, a header, or a scroll view already pinned at its dismiss
	/// boundary) — in that case the recognizer uses its normal flow,
	/// including the overscroll-on-began shortcut.
	private weak var activeScrollView: UIScrollView?

	/// Three-state machine for scroll-aware gesture coordination. Only used
	/// when `shouldRecognizeSimultaneouslyWith` cached a cooperating scroll
	/// view into `activeScrollView` before `.began` fires.
	///
	/// - `.none`: no scroll view — recognizer behaves as before.
	/// - `.observing`: scroll view is active and consuming the drag; we are
	///   watching for it to bottom out at the top of its content. The sheet
	///   transition has NOT been started.
	/// - `.driving(scrollView, lockedOffset)`: the scroll view has hit its
	///   top and the sheet transition is in progress. Each `.changed` tick
	///   pins the scroll view's `contentOffset` to `lockedOffset` so the two
	///   gestures don't fight.
	private enum ScrollState {
		case none
		case observing(UIScrollView)
		case driving(UIScrollView)
	}

	private var scrollState: ScrollState = .none

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

	/// Allow this recognizer to run alongside an inner scroll view's pan
	/// gesture so the two can coordinate in `handle` — the list scrolls
	/// normally until it bottoms out, at which point further drag hands
	/// off to the sheet dismiss transition. Without this, UIKit would
	/// make the scroll view's pan and our pan mutually exclusive.
	///
	/// This is also how we *discover* the scroll view in the first place:
	/// UIKit only calls this delegate for gestures whose hit regions
	/// overlap — a scroll view whose pan UIKit offers here is, by
	/// definition, the one sitting under the user's finger right now.
	/// So there is no need to ask the view controller which scroll view
	/// it owns: we pick up whatever UIKit reports as geometrically
	/// relevant.
	///
	/// Acceptance criteria for coordination:
	///   1. `other` must be a `UIPanGestureRecognizer` attached to a
	///      `UIScrollView` that lives inside `target` (our transition
	///      view). Random unrelated pans are rejected.
	///   2. The scroll view must still have room to scroll **away from**
	///      the dismiss edge. If it's already pinned at the boundary
	///      (e.g. table already at the top in a bottom sheet), there is
	///      nothing to hand off from and the normal swipe-dismiss flow
	///      is the correct behavior — we return `false` and let the
	///      scroll view lose.
	///
	/// When both hold, we cache `activeScrollView` so `.began` can enter
	/// scroll-aware `.observing` mode without re-doing the lookup.
	func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
	) -> Bool {
		guard
			let target,
			let pan = other as? UIPanGestureRecognizer,
			let scrollView = pan.view as? UIScrollView,
			scrollView.isDescendant(of: target),
			let dismissEdge = preferredScrollDismissEdge(),
			scrollViewCanScrollAway(scrollView, from: dismissEdge)
		else {
			return false
		}
		activeScrollView = scrollView
		return true
	}

	/// Picks the dismiss edge that makes sense to coordinate with a scroll
	/// view. We prefer vertical edges because the built-in sheets scroll
	/// vertically; horizontal edges are used only when no vertical one is
	/// configured. Returning `nil` means coordination is disabled for this
	/// recognizer (no edges at all).
	private func preferredScrollDismissEdge() -> Edge? {
		if edges.contains(.bottom) { return .bottom }
		if edges.contains(.top) { return .top }
		if edges.contains(.trailing) { return .trailing }
		if edges.contains(.leading) { return .leading }
		return nil
	}

	/// True when `scrollView` still has content to scroll in the direction
	/// *opposite* to `dismissEdge` — i.e. a drag toward `dismissEdge` will
	/// first reveal more content and only later reach the boundary from
	/// which the sheet should take over.
	///
	/// If the scroll view is already at that boundary (e.g. a table sitting
	/// at its top inside a bottom sheet when the touch lands), there is no
	/// content to scroll: coordination would immediately fall through to
	/// "hand off", which is indistinguishable from the normal swipe flow.
	/// In that case we return `false` and let UIKit arbitrate the two
	/// gestures as usual — our recognizer wins the drag and dismisses the
	/// sheet without the extra observing phase.
	private func scrollViewCanScrollAway(_ scrollView: UIScrollView, from dismissEdge: Edge) -> Bool {
		!isScrollViewAtDismissBoundary(scrollView, for: dismissEdge)
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
			// Scroll-aware mode: only when the touch actually landed
			// inside the tracked scroll view (detected via
			// `shouldRecognizeSimultaneouslyWith`, which UIKit only
			// calls for geometrically-conflicting gestures). In that
			// case we defer the transition decision to the first
			// `.changed` tick so the scroll view can consume the drag
			// until it bottoms out.
			//
			// When the touch started outside the scroll view — e.g. on
			// a grabber or a header label — `activeScrollView` is nil
			// and we fall through to the normal flow, including the
			// overscroll-on-began shortcut for drags that go away from
			// the dismiss edge.
			if let scrollView = activeScrollView {
				scrollState = .observing(scrollView)
				return
			}
			scrollState = .none
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
			// Scroll-aware hand-off: while the scroll view is consuming the
			// drag, watch for the moment it hits its top *and* the user is
			// still dragging toward the dismiss edge. At that moment reset
			// the gesture's translation baseline so the sheet doesn't jump,
			// flip to `.driving`, and start the interactive transition.
			if case .observing(let scrollView) = scrollState {
				// Direction is taken from instantaneous velocity, not
				// accumulated translation: the scroll view may have been
				// scrolled far before the user reverses and starts dragging
				// toward the dismiss edge. Total translation at that point
				// could still be negative — velocity captures the fact that
				// motion is now going the other way.
				let v = velocity(in: view)
				let dismissEdge: Edge?
				if edges.contains(.bottom), v.y > 0 { dismissEdge = .bottom }
				else if edges.contains(.top), v.y < 0 { dismissEdge = .top }
				else if edges.contains(.trailing), v.x > 0 { dismissEdge = .trailing }
				else if edges.contains(.leading), v.x < 0 { dismissEdge = .leading }
				else { dismissEdge = nil }
				if let dismissEdge, isScrollViewAtDismissBoundary(scrollView, for: dismissEdge) {
					// Baseline reset for OUR recognizer: the translation
					// accumulated during the observing phase belongs to
					// the scroll view, not to the sheet. Zeroing it means
					// the sheet transition starts from the current finger
					// position — no visual jump.
					setTranslation(.zero, in: view)
					// Baseline reset for the SCROLL VIEW's pan as well:
					// the scroll view computes its `contentOffset` from
					// its pan's accumulated translation, so zeroing that
					// translation here, and on every subsequent tick
					// while we drive, freezes the content in place
					// without ever touching `contentOffset` directly.
					scrollView.panGestureRecognizer.setTranslation(.zero, in: scrollView)
					scrollState = .driving(scrollView)
					edge = nil
					begin()
				}
				return
			}
			// `.driving` — sheet transition is live. Each tick we zero
			// the scroll view's pan translation so its own handler sees
			// "no movement since last frame" and leaves `contentOffset`
			// untouched. `contentOffset` is never written by us.
			//
			// If the user reverses past the origin, tear down the sheet
			// transition and hand control back to the scroll view: we
			// stop zeroing its translation, reset our own, and fall back
			// to `.observing`. Overscroll is intentionally NOT entered
			// here — a scroll view above the dismiss gesture owns the
			// "drag past the top" gesture semantically.
			if case .driving(let scrollView) = scrollState {
				scrollView.panGestureRecognizer.setTranslation(.zero, in: scrollView)
				let rawPercent = percent
				if rawPercent < 0 {
					finish(completed: false, immediately: true)
					setTranslation(.zero, in: view)
					scrollState = .observing(scrollView)
					return
				}
				let clamped = min(1, max(0, rawPercent))
				update(percent: clamped)
				return
			}
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
			// In `.observing` we never started a transition — nothing to
			// end, just reset state so the next gesture starts fresh.
			if case .observing = scrollState {
				scrollState = .none
				activeScrollView = nil
				return
			}
			guard wasBegun else {
				return
			}
			let completed = p > 0.35 || v > 800
			finish(completed: completed)
			scrollState = .none

		case .failed, .cancelled:
			if overscrollEdge != nil {
				animateOverscrollReturn()
				overscrollEdge = nil
				stop()
				return
			}
			if case .observing = scrollState {
				scrollState = .none
				activeScrollView = nil
				return
			}
			guard wasBegun else { return }
			finish(completed: false)
			scrollState = .none

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
		activeScrollView = nil
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

	/// True when the scroll view has bottomed out on the side that the
	/// sheet dismisses toward — the moment at which further drag should
	/// stop scrolling and start driving the sheet's dismiss transition.
	///
	/// The "boundary" depends on the dismiss edge:
	///   - `.bottom` sheet dismisses by dragging **down**, so the scroll
	///     view hands off at its **top** (`-adjustedContentInset.top`),
	///   - `.top` sheet dismisses by dragging **up**, so the scroll view
	///     hands off at its **bottom** (content fully scrolled),
	///   - `.leading` / `.trailing` — analogously along the x axis.
	///
	/// Offsets are measured against `adjustedContentInset` rather than
	/// `0`, so scroll views with non-zero insets (large titles, grabbers,
	/// safe-area bars) hand off at the right moment. A half-point cushion
	/// absorbs sub-pixel rounding that `UIScrollView` introduces during
	/// bouncing.
	private func isScrollViewAtDismissBoundary(_ scrollView: UIScrollView, for edge: Edge) -> Bool {
		let inset = scrollView.adjustedContentInset
		let offset = scrollView.contentOffset
		let size = scrollView.bounds.size
		let content = scrollView.contentSize
		let cushion: CGFloat = 0.5
		switch edge {
		case .bottom:
			return offset.y <= -inset.top + cushion
		case .top:
			let maxY = max(-inset.top, content.height + inset.bottom - size.height)
			return offset.y >= maxY - cushion
		case .trailing:
			return offset.x <= -inset.left + cushion
		case .leading:
			let maxX = max(-inset.left, content.width + inset.right - size.width)
			return offset.x >= maxX - cushion
		}
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
		// Scroll-aware case: a cooperating scroll view has already been
		// discovered and cached by `shouldRecognizeSimultaneouslyWith`
		// (UIKit invokes that delegate for geometrically-conflicting
		// gestures before either transitions out of `.possible`, so by
		// the time we get here `activeScrollView` is already set if the
		// touch landed inside an inner scroll view). In that case the
		// scroll view will consume the drag until it bottoms out, after
		// which the sheet takes over — so we must begin the gesture
		// regardless of the initial drag direction (including the
		// direction AWAY from the dismiss edge, which would normally
		// fail here) so we can observe it and hand off later.
		let touchIsInTrackedScrollView = activeScrollView != nil
		guard isDismissDirection || isOverscrollDirection || touchIsInTrackedScrollView else {
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
