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
		/// The rubber-band asymptote is the `limit` passed in by the gesture
		/// recognizer (space up to the safe area), not the view's full
		/// dimension — so the stretch visibly tops out before hitting the
		/// status bar / notch, matching native pageSheet behavior.
		///
		/// @ai-generated(guided)
		public static func stretch(constant: CGFloat = 0.3) -> Overscroll {
			Overscroll { view, edge, distance, limit in
				let isVertical = edge == .top || edge == .bottom
				let dimension = isVertical ? view.bounds.height : view.bounds.width
				guard dimension > 0 else { return }
				guard limit > 0 else {
					// No room to grow — view is already at/past safe area.
					view.transform = .identity
					return
				}

				let stretch = rubberBand(distance, dimension: limit, constant: constant)
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
		/// The rubber-band asymptote is `limit` (free space to safe area),
		/// so the shift visibly tops out before the view crosses into the
		/// status-bar / notch region.
		///
		/// @ai-generated(guided)
		public static func offset(constant: CGFloat = 0.3) -> Overscroll {
			Overscroll { view, edge, distance, limit in
				guard limit > 0 else {
					view.transform = .identity
					return
				}
				let shift = rubberBand(distance, dimension: limit, constant: constant)

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
