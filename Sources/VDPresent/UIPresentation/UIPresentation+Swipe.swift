import SwiftUI

public extension UIPresentation.Interactivity {

	static var swipe: UIPresentation.Interactivity {
		swipe(to: .bottom)
	}

	@_disfavoredOverload
	static func swipe(
		to edge: Edge,
		overscroll: Overscroll? = nil
	) -> UIPresentation.Interactivity {
		.swipe(to: NSDirectionalRectEdge(edge), overscroll: overscroll)
	}

	static func swipe(
		to edges: NSDirectionalRectEdge,
		overscroll: Overscroll? = nil
	) -> UIPresentation.Interactivity {
		var config = SwipeConfiguration.default(edges: edges)
		config.overscroll = overscroll
		return swipe(configuration: config)
	}

	static func swipe(
		configuration: SwipeConfiguration
	) -> UIPresentation.Interactivity {
		UIPresentation.Interactivity { context, observer in
			let controller = context.viewController
			let view = context.container
			let tapRec = view.gestureRecognizers?.compactMap { $0 as? TransitionContainerTapRecognizer }.first
			let swipeRec = view.gestureRecognizers?.compactMap { $0 as? SwipeGestureRecognizer }.first
			let tapRecognizer = tapRec ?? TransitionContainerTapRecognizer()
			if tapRec == nil {
				view.addGestureRecognizer(tapRecognizer)
			}
			tapRecognizer.isEnabled = true
			tapRecognizer.onTap = { [weak controller] in
				controller?.hide()
			}

			let swipeRecognizer = swipeRec ?? SwipeGestureRecognizer()
			swipeRecognizer.isEnabled = true
			swipeRecognizer.edges = configuration.edges
			swipeRecognizer.startFromEdges = context.environment.swipeFromEdge
			swipeRecognizer.fullDuration = context.animation.duration
			swipeRecognizer.shouldStart = { [weak controller] edge in
				guard let controller else { return false }
				return configuration.shouldStart(for: context, from: controller, to: edge)
			}
			swipeRecognizer.update = { [weak controller] percent, edge in
				guard let controller else { return .prevent }
				return observer(configuration.context(for: context, from: controller, to: edge), percent)
			}
			swipeRecognizer.overscroll = { [weak view = context.view] edge, distance, limit in
				guard let view else { return }
				configuration.overscroll?.apply(view, edge, distance, limit)
			}
			// Let the presented controller expose an inner scroll view
			// (e.g. a `UITableView` inside a bottom sheet). The swipe
			// recognizer then coordinates with the scroll view's pan:
			// the list scrolls normally until it reaches its top, at
			// which point further downward drag hands off to the sheet
			// dismiss transition — matching the native sheet feel.
			swipeRecognizer.trackedScrollView = { [weak controller] in
				guard let controller else { return nil }
				if #available(iOS 15.0, *) {
					// Query the controller for the scroll view that
					// governs the configured dismiss edge. For a bottom
					// sheet that's `.bottom`; for a side sheet it would
					// be `.leading`/`.trailing`. Prefer vertical edges
					// because a scroll view consuming the drag only
					// makes sense along its own scroll axis, and the
					// built-in sheets scroll vertically.
					let edges = configuration.edges
					let preferred: NSDirectionalRectEdge
					if edges.contains(.bottom) { preferred = .bottom }
					else if edges.contains(.top) { preferred = .top }
					else if edges.contains(.trailing) { preferred = .trailing }
					else if edges.contains(.leading) { preferred = .leading }
					else { return nil }
					return controller.contentScrollView(for: preferred)
				}
				return nil
			}
			swipeRecognizer.target = context.view
			if swipeRec == nil {
				view.addGestureRecognizer(swipeRecognizer)
			}
		} uninstaller: { context in
			context.container.gestureRecognizers?
				.compactMap { $0 as? TransitionContainerTapRecognizer }
				.forEach(context.container.removeGestureRecognizer)
			context.container.gestureRecognizers?
				.compactMap { $0 as? SwipeGestureRecognizer }
				.forEach(context.container.removeGestureRecognizer)
		}
	}

	struct SwipeConfiguration {

		public let edges: NSDirectionalRectEdge
		private let _shouldStart: (UIPresentation.Context, UIViewController, Edge) -> Bool
		private let _moveToEdgeContext: (UIPresentation.Context, UIViewController, Edge) -> UIPresentation.Context

		/// Controls how the view responds when the user drags *past* the
		/// starting position (negative progress — away from the dismiss edge).
		///
		/// See `UIPresentation.Interactivity.Overscroll` for built-in handlers
		/// (`.stretch`, `.offset`). When `nil`, overscroll is ignored and the
		/// view stays pinned at its starting position.
		///
		/// TODO: edge cases not yet handled:
		///   - Controller is dismissed programmatically mid-drag: the view may
		///     be removed while still carrying an overscroll transform.
		///   - A new gesture starts while the return-to-identity animation is
		///     still running: the new gesture's baseline will be the in-flight
		///     (partially-restored) transform rather than identity.
		public var overscroll: UIPresentation.Interactivity.Overscroll?

		public init(
			edges: NSDirectionalRectEdge,
			shouldStart: @escaping (UIPresentation.Context, UIViewController, Edge) -> Bool,
			moveToEdgeContext: @escaping (UIPresentation.Context, UIViewController, Edge) -> UIPresentation.Context,
			overscroll: UIPresentation.Interactivity.Overscroll? = nil
		) {
			self.edges = edges
			_shouldStart = shouldStart
			_moveToEdgeContext = moveToEdgeContext
			self.overscroll = overscroll
		}

		public func shouldStart(
			for context: UIPresentation.Context,
			from controller: UIViewController,
			to edge: Edge
		) -> Bool {
			_shouldStart(context, controller, edge)
		}

		public func context(
			for context: UIPresentation.Context,
			from controller: UIViewController,
			to edge: Edge
		) -> UIPresentation.Context {
			_moveToEdgeContext(context, controller, edge)
		}

		public static func `default`(
			edges: NSDirectionalRectEdge
		) -> SwipeConfiguration {
			SwipeConfiguration(edges: edges) { context, controller, edge in
				guard
					edges.contains(NSDirectionalRectEdge(edge)),
					let i = context.viewControllers.to.firstIndex(where: controller.isDescendant)
				else {
					return false
				}
				return i > 0
			} moveToEdgeContext: { context, controller, edge in
				UIPresentation.Context(
					direction: .removal,
					controller: controller,
					container: { context.for($0).container },
					fromViewControllers: context.viewControllers.to,
					toViewControllers: Array(
						context.viewControllers.to.prefix(
							upTo: context.viewControllers.to.firstIndex(where: controller.isDescendant)
								?? context.viewControllers.to.count - 1
						)
					),
					views: { context.for($0).view },
					animated: true,
					animation: context.animation,
					isInteractive: true,
					cache: context.cache,
					updateStatusBar: context.updateStatusBar,
					presentation: {
						context.for($0).presentation.environment(\.currentSwipeEdge, edge)
					}
				)
			}
		}
	}
}

public extension UIPresentation.Interactivity {

	/// Describes how a view should respond to overscroll — dragging past the
	/// starting position of a swipe, away from the dismiss edge.
	///
	/// An `Overscroll` is a thin wrapper around a closure that applies a
	/// transform to a view given the drag distance and a pre-computed
	/// `limit` — the asymptote the rubber-band curve should approach.
	///
	/// `limit` is computed *once* by `SwipeGestureRecognizer` at the moment
	/// overscroll is entered and represents the free space (in points) on
	/// the side the view will extend toward, minus a small cushion, so the
	/// view never reaches the window's safe area. This mirrors the native
	/// pageSheet feel: the stretch gets arbitrarily hard to pull further as
	/// the edge approaches (but never reaches) the status-bar / notch line.
	///
	/// Built-in factories: `.stretch` (scale along the drag axis, anchor
	/// opposite edge pinned) and `.offset` (translate along the drag axis,
	/// no scale).
	///
	/// When the gesture ends in overscroll, the swipe recognizer animates
	/// the view back to identity automatically — the `apply` closure must
	/// not install its own restore animation.
	struct Overscroll {

		/// Applies the overscroll transform to `view` for the given drag
		/// `edge`, raw `distance` in points (`>= 0`, before rubber-banding),
		/// and `limit` in points — the asymptote the rubber-band curve must
		/// approach. If `limit == 0` the transform should be identity
		/// (the view is already flush with the safe area).
		public let apply: (UIView, Edge, CGFloat, CGFloat) -> Void

		public init(apply: @escaping (UIView, Edge, CGFloat, CGFloat) -> Void) {
			self.apply = apply
		}

		/// Stretches the view along the drag axis using rubber-band resistance,
		/// keeping the edge *opposite* the drag pinned in place.
		///
		/// Use this for sheets/pageSheets that are flush with the screen edge:
		/// dragging a bottom sheet further up grows it upward, bottom stays put.
		///
		/// ## Two ceilings, whichever is lower
		///
		/// The stretch is bounded by `min(visualCap, safeAreaCap)` where
		/// - `safeAreaCap` is the free space up to the window's safe area
		///   (computed by the gesture recognizer, passed in as `limit`),
		/// - `visualCap = dimension * maxStretchRatio` is the point past
		///   which scaling starts to visibly distort content (default 15%
		///   of the view's dimension along the drag axis).
		///
		/// Small sheets (far from the safe area) are bounded by `visualCap`;
		/// large sheets that are flush with the screen edge are bounded by
		/// `safeAreaCap`. The cushion in `safeAreaCap` is intentionally
		/// small — crossing the safe area "a tiny bit" is acceptable, fully
		/// crossing it (which triggers a `safeAreaInsets` recalc) is not.
		///
		/// ## Curve: 45° cap
		///
		/// The rubber-band uses `constant = 1`, which gives `b'(0) = 1`
		/// (exactly 45°) and `b'(x) < 1` everywhere else — so the stretch
		/// never outruns the finger. This is the steepest curve allowed by
		/// the "tangent ≤ 45°" rule while still respecting the asymptote.
		/// A softer constant just makes the start feel dead without any
		/// benefit at the top.
		///
		/// - Parameter maxStretchRatio: Visual cap as a fraction of the
		///   view's dimension along the drag axis. Default `0.08` —
		///   smaller than `.offset` because scaling distorts content
		///   more aggressively than plain translation at the same
		///   magnitude.
		///
		/// @ai-generated(guided)
		public static func stretch(maxStretchRatio: CGFloat = 0.08) -> Overscroll {
			Overscroll { view, edge, distance, safeAreaCap in
				let isVertical = edge == .top || edge == .bottom
				let dimension = isVertical ? view.bounds.height : view.bounds.width
				guard dimension > 0 else { return }

				let visualCap = dimension * maxStretchRatio
				// `safeAreaCap` is authoritative: 0 means "no room" (view
				// is already flush with the safe area, or we couldn't
				// measure — recognizer has no window). In either case the
				// correct behavior is to not stretch.
				let cap = min(visualCap, safeAreaCap)
				guard cap > 0 else {
					view.transform = .identity
					return
				}

				// `constant = 1` → tangent at 0 is exactly 1 (45°), and
				// `b(x) → cap` as `x → ∞`. This is the steepest curve that
				// never outruns the finger.
				let stretch = rubberBand(distance, dimension: cap, constant: 1)
				let scale = (dimension + stretch) / dimension

				// Pin the edge opposite the drag. For `.bottom` (sheet dragged
				// up), bottom stays put → center moves up by stretch/2.
				let translate: CGAffineTransform
				switch edge {
				case .bottom:   translate = CGAffineTransform(translationX: 0, y: -stretch / 2)
				case .top:      translate = CGAffineTransform(translationX: 0, y:  stretch / 2)
				case .trailing: translate = CGAffineTransform(translationX: -stretch / 2, y: 0)
				case .leading:  translate = CGAffineTransform(translationX:  stretch / 2, y: 0)
				}

				let scaleT = isVertical
					? CGAffineTransform(scaleX: 1, y: scale)
					: CGAffineTransform(scaleX: scale, y: 1)

				// Order matters: scale first, then translate. `concatenating`
				// post-multiplies (p' = B(A(p))), so `a.concatenating(b)` means
				// "do a, then b". Doing translate first would cause the translate
				// to be scaled by `scale`, pulling the anchor edge off the
				// screen edge.
				view.transform = scaleT.concatenating(translate)
			}
		}

		/// Translates the view along the drag axis using rubber-band resistance,
		/// without scaling.
		///
		/// Use this for sheets that have margins from the screen edges (e.g.
		/// a floating card) — stretching would look wrong, but following the
		/// finger with resistance preserves the tactile feel.
		///
		/// Uses the same two-ceiling rule as `.stretch`:
		/// `min(visualCap, safeAreaCap)`, where `visualCap = dimension *
		/// maxOffsetRatio`. Curve uses `constant = 1` — tangent ≤ 45°, so
		/// the view never outruns the finger.
		///
		/// - Parameter maxOffsetRatio: Visual cap as a fraction of the
		///   view's dimension along the drag axis. Default `0.15`.
		///
		/// @ai-generated(guided)
		public static func offset(maxOffsetRatio: CGFloat = 0.15) -> Overscroll {
			Overscroll { view, edge, distance, safeAreaCap in
				let isVertical = edge == .top || edge == .bottom
				let dimension = isVertical ? view.bounds.height : view.bounds.width
				guard dimension > 0 else { return }

				let visualCap = dimension * maxOffsetRatio
				// See `.stretch`: `safeAreaCap == 0` means "no room",
				// not "unknown — use visual cap".
				let cap = min(visualCap, safeAreaCap)
				guard cap > 0 else {
					view.transform = .identity
					return
				}
				let shift = rubberBand(distance, dimension: cap, constant: 1)

				// Move *away* from the dismiss edge: `.bottom` → drag up → -y.
				let translate: CGAffineTransform
				switch edge {
				case .bottom:   translate = CGAffineTransform(translationX: 0, y: -shift)
				case .top:      translate = CGAffineTransform(translationX: 0, y:  shift)
				case .trailing: translate = CGAffineTransform(translationX: -shift, y: 0)
				case .leading:  translate = CGAffineTransform(translationX:  shift, y: 0)
				}
				view.transform = translate
			}
		}
	}
}

public extension UIPresentation.Environment {

	var swipeFromEdge: Bool {
		get { self[\.swipeFromEdge] ?? false }
		set { self[\.swipeFromEdge] = newValue }
	}

	var currentSwipeEdge: Edge? {
		get { self[\.currentSwipeEdge] ?? nil }
		set { self[\.currentSwipeEdge] = newValue }
	}
}
