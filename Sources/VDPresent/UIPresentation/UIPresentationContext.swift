import UIKit

public extension UIPresentation {

	struct Context {

		public var viewController: UIViewController {
			_controller ?? UIViewController()
		}

		public var view: UIStackEffectView {
			views(viewController)
		}

		public var container: UIStackControllerCanvas {
			_container(viewController)
		}

		public var animated: Bool
		public var isInteractive: Bool
		public var cache: Cache
		public var animation: UIKitAnimation
		public var viewControllers: Controllers
		public var direction: TransitionDirection

		public var ownDirection: TransitionDirection {
			guard isChangingController else { return .insertion }
			return viewControllers.to.contains(viewController) ? .insertion : .removal
		}

		public var environment: UIPresentation.Environment {
			presentation.environment
		}

		/// The presentation assigned to this controller.
		public var presentation: UIPresentation {
			_presentation(viewController)
		}

		private weak var _controller: UIViewController?
		private let views: (UIViewController) -> UIStackEffectView
		private let _container: (UIViewController) -> UIStackControllerCanvas
		private let _presentation: (UIViewController) -> UIPresentation
		private let _updateStatusBar: (UIStatusBarStyle, UIStatusBarAnimation) -> Void

		/// Creates a context from a pre-built `Controllers` struct.
		///
		/// - Parameters:
		///   - direction: Whether the transition is an insertion or removal.
		///   - controller: The view controller this context represents.
		///   - container: Closure resolving a controller to its container canvas.
		///   - controllers: Pre-built `Controllers` with full and visible slices.
		///   - views: Closure resolving a controller to its effect wrapper view.
		///   - animated: Whether the transition is animated.
		///   - animation: The UIKit animation configuration.
		///   - isInteractive: Whether the transition is driven by a gesture.
		///   - cache: Shared cache for per-transition state.
		///   - updateStatusBar: Callback to update the status bar appearance.
		///   - presentation: Closure resolving a controller to its presentation.
		/// @ai-generated(solo)
		public init(
			direction: TransitionDirection,
			controller: UIViewController,
			container: @escaping (UIViewController) -> UIStackControllerCanvas,
			controllers: Controllers,
			views: @escaping (UIViewController) -> UIStackEffectView,
			animated: Bool,
			animation: UIKitAnimation,
			isInteractive: Bool,
			cache: Cache,
			updateStatusBar: @escaping (UIStatusBarStyle, UIStatusBarAnimation) -> Void,
			presentation: @escaping (UIViewController) -> UIPresentation
		) {
			self.direction = direction
			_controller = controller
			_container = container
			viewControllers = controllers
			self.views = views
			self.animated = animated
			self.isInteractive = isInteractive
			self.cache = cache
			_updateStatusBar = updateStatusBar
			_presentation = presentation
			self.animation = animation
		}

		public func updateStatusBar(style: UIStatusBarStyle, animation: UIStatusBarAnimation = .fade) {
			_updateStatusBar(style, animation)
		}

		public func `for`(_ controller: UIViewController) -> Self {
			var result = self
			result._controller = controller
			return result
		}
	}
}

public extension UIPresentation.Context {

	/// Holds both the full stack arrays and the visible slices used for transitions.
	///
	/// `fullFrom`/`fullTo` contain every controller in the stack before/after the transition.
	/// `from`/`to` contain only the "visible slice" — controllers relevant to animation,
	/// computed by walking from the top downward and stopping after the first controller
	/// whose presentation has `overCurrentContext == false`. This avoids running the
	/// prepare/animate/complete pipeline for deeply buried controllers that are hidden
	/// both before and after the transition.
	///
	/// Structural operations (addChild, removeFromParent, viewControllers assignment)
	/// use the `full*` arrays. Animation operations (prepare, animate, complete, z-ordering)
	/// use the visible `from`/`to` arrays.
	/// @ai-generated(solo)
	struct Controllers {

		/// Visible slice of the from-stack — only controllers relevant to animation.
		public var from: [UIViewController] {
			get { _fromViewControllers.compactMap(\.value) }
			set { _fromViewControllers = newValue.map { Weak($0) } }
		}

		/// Visible slice of the to-stack — only controllers relevant to animation.
		public var to: [UIViewController] {
			get { _toViewControllers.compactMap(\.value) }
			set { _toViewControllers = newValue.map { Weak($0) } }
		}

		/// Full from-stack — every controller before the transition.
		public var fullFrom: [UIViewController] {
			get { _fullFromViewControllers.compactMap(\.value) }
			set { _fullFromViewControllers = newValue.map { Weak($0) } }
		}

		/// Full to-stack — every controller after the transition.
		public var fullTo: [UIViewController] {
			get { _fullToViewControllers.compactMap(\.value) }
			set { _fullToViewControllers = newValue.map { Weak($0) } }
		}

		private var _fromViewControllers: [Weak<UIViewController>]
		private var _toViewControllers: [Weak<UIViewController>]
		private var _fullFromViewControllers: [Weak<UIViewController>]
		private var _fullToViewControllers: [Weak<UIViewController>]

		/// Creates controllers with both full and visible arrays.
		///
		/// - Parameters:
		///   - fullFrom: Complete from-stack.
		///   - fullTo: Complete to-stack.
		///   - visibleFrom: Visible slice of from-stack (defaults to `fullFrom`).
		///   - visibleTo: Visible slice of to-stack (defaults to `fullTo`).
		/// @ai-generated(solo)
		public init(
			fullFrom: [UIViewController],
			fullTo: [UIViewController],
			visibleFrom: [UIViewController]? = nil,
			visibleTo: [UIViewController]? = nil
		) {
			_fullFromViewControllers = fullFrom.map { Weak($0) }
			_fullToViewControllers = fullTo.map { Weak($0) }
			_fromViewControllers = (visibleFrom ?? fullFrom).map { Weak($0) }
			_toViewControllers = (visibleTo ?? fullTo).map { Weak($0) }
		}

		/// Backward-compatible init — full arrays equal visible arrays.
		public init(
			fromViewControllers: [UIViewController],
			toViewControllers: [UIViewController]
		) {
			self.init(fullFrom: fromViewControllers, fullTo: toViewControllers)
		}

		public subscript(_ key: UITransitionContextViewControllerKey) -> [UIViewController] {
			switch key {
			case .from: return from
			case .to: return to
			default: return []
			}
		}

		/// Walks the stack top-down, including each controller until hitting one
		/// whose presentation has `overCurrentContext == false` (i.e. it's opaque/fullscreen).
		/// That controller is included but iteration stops — everything below is invisible.
		///
		/// - Parameters:
		///   - stack: The full stack to compute the visible slice of.
		///   - presentation: Resolves a controller to its presentation.
		/// - Returns: The visible slice, preserving original order (bottom to top).
		/// @ai-generated(solo)
		static func visibleSlice(
			of stack: [UIViewController],
			presentation: (UIViewController) -> UIPresentation
		) -> [UIViewController] {
			guard !stack.isEmpty else { return [] }
			var startIndex = stack.count - 1
			// Walk from top downward. Always include top. Stop after first non-overCurrentContext.
			for i in stride(from: stack.count - 1, through: 0, by: -1) {
				startIndex = i
				if !presentation(stack[i]).environment.overCurrentContext {
					break
				}
			}
			return Array(stack[startIndex...])
		}
	}
}

public extension UIPresentation.Context.Controllers {

	/// Controllers being removed — present in full from-stack but not in full to-stack.
	var fullToRemove: [UIViewController] {
		fullFrom.filter { !fullTo.contains($0) }
	}

	/// Controllers being inserted — present in full to-stack but not in full from-stack.
	var fullToInsert: [UIViewController] {
		fullTo.filter { !fullFrom.contains($0) }
	}

	/// Controllers being removed from the visible slice.
	var toRemove: [UIViewController] {
		from.filter { !to.contains($0) }
	}

	/// Controllers being inserted into the visible slice.
	var toInsert: [UIViewController] {
		to.filter { !from.contains($0) }
	}

	/// Merges `from` and `to` into a single iteration order for transitions.
	///
	/// Preserves relative order from both arrays to minimise z-index jumps
	/// during animation. Old and new top controllers are always placed at
	/// the end: during insertion the new top is frontmost; during removal
	/// the old top is.
	///
	/// Fast path: the common prefix (unchanged bottom of the stack) is
	/// emitted directly — covers the typical push/pop case. Remaining
	/// departing controllers are inserted near their original `from`
	/// neighbours via a pre-built index.
	/// @ai-generated(guided)
	func all(_ direction: TransitionDirection) -> [UIViewController] {
		guard !from.isEmpty else { return to }
		guard !to.isEmpty else { return from }

		// --- Common prefix — fast path for push / pop ---
		var prefixEnd = 0
		while prefixEnd < from.count, prefixEnd < to.count,
		      from[prefixEnd] === to[prefixEnd]
		{
			prefixEnd += 1
		}

		// When one array is entirely a prefix of the other no merge is needed.
		// Push (from ⊂ to): new top is already last in `to`.
		// Pop-prefix (to ⊂ from): departing controllers append in from-order,
		// old top is naturally last.
		if prefixEnd == from.count { return to }
		if prefixEnd == to.count { return to + from[prefixEnd...] }

		var result = Array(to[..<prefixEnd])

		// --- Index maps: controller → position. O(n + m) ---
		var fromIndex: [ObjectIdentifier: Int] = Dictionary(minimumCapacity: from.count)
		for (i, vc) in from.enumerated() {
			fromIndex[ObjectIdentifier(vc)] = i
		}
		let toSet = Set(to.map { ObjectIdentifier($0) })

		// --- Merge the tails ---
		// `to` tail is the base; departing controllers are inserted near
		// their original right neighbour from `from`.
		let toTail = Array(to[prefixEnd...])
		let removed = from[prefixEnd...].filter { !toSet.contains(ObjectIdentifier($0)) }

		var merged = toTail
		for vc in removed {
			let fi = fromIndex[ObjectIdentifier(vc)]!
			// Find nearest right neighbour in `from` that exists in `merged`.
			var insertAt = merged.count
			for j in (fi + 1) ..< from.count {
				if let mi = merged.firstIndex(where: { $0 === from[j] }) {
					insertAt = mi
					break
				}
			}
			merged.insert(vc, at: insertAt)
		}
		result.append(contentsOf: merged)

		// --- Ensure old & new tops are at the end ---
		// Only move tops that are *changing* (not in both stacks) — a remaining
		// controller that happens to be top should keep its merged position.
		let oldTop = from.last
		let newTop = to.last
		if let old = oldTop, old !== newTop, let new = newTop {
			let oldIsChanging = !toSet.contains(ObjectIdentifier(old))
			let newIsChanging = fromIndex[ObjectIdentifier(new)] == nil
			// Collect which changing tops need to be pulled to the end.
			var tops: [UIViewController] = []
			if direction == .insertion {
				// Push: old behind, new in front
				if oldIsChanging { tops.append(old) }
				if newIsChanging { tops.append(new) }
			} else {
				// Pop: new behind, old in front (old animates out on top)
				if newIsChanging { tops.append(new) }
				if oldIsChanging { tops.append(old) }
			}
			if !tops.isEmpty {
				let topSet = Set(tops.map { ObjectIdentifier($0) })
				result.removeAll { topSet.contains(ObjectIdentifier($0)) }
				result.append(contentsOf: tops)
			}
		}

		return result
	}

	/// Whether the visible top controller is unchanged.
	var isTopTheSame: Bool {
		from.last === to.last
	}

	/// Whether the full-stack top controller is unchanged.
	/// Used for appearance transition guards — UIKit appearance is structural.
	var isFullTopTheSame: Bool {
		fullFrom.last === fullTo.last
	}
}

public extension UIPresentation.Context {

	final class Cache {

		private var values: [PartialKeyPath<UIPresentation.Context>: Any] = [:]

		public subscript<T>(_ keyPath: ReferenceWritableKeyPath<UIPresentation.Context, T>) -> T? {
			get { values[keyPath] as? T }
			set { values[keyPath] = newValue }
		}

		public init() {}
	}
}

extension UIPresentation.Context {

	var isChangingController: Bool {
		!viewControllers.to.contains(viewController) || !viewControllers.from.contains(viewController)
	}

	var isRemainingController: Bool {
		!isChangingController
	}

	var isTopController: Bool {
		topViewControllers.contains(viewController)
	}

	var isSecondController: Bool {
		secondViewControllers.contains(viewController)
	}

	var needHide: Bool {
		// Use full to-stack: visibility depends on all controllers above, not just visible slice.
		let all = viewControllers.fullTo
		guard let j = all.firstIndex(of: viewController) else { return true }
		for (index, vc) in all.enumerated().reversed() {
			if index == j {
				return false
			}
			let context = self.for(vc)
			if !context.environment.overCurrentContext {
				return true
			}
		}
		return false
	}

	var needAnimate: Bool {
		isTopController && !viewControllers.isTopTheSame || isChangingController && !needHide
	}

	/// Whether this behind-controller should be frozen (no own contentTransition)
	/// based on the top controller's `behindBehavior` and `transitionID`.
	///
	/// "Behind" means a changing controller that is not the top of the transition
	/// (e.g. a departing VC behind the new top during a replace, or a newly
	/// inserted VC behind the new top).
	///
	/// The top controller's `behindBehavior` decides whether such controllers
	/// animate their own contentTransition or stay frozen.
	var isBehindFrozen: Bool {
		// Only applies to non-top changing controllers.
		guard isChangingController, !isTopController else { return false }
		// The top controller drives the decision.
		let top = direction == .insertion ? viewControllers.to.last : viewControllers.from.last
		guard let top else { return true }
		let topContext = self.for(top)
		// overCurrentContext top means behind controllers are visible — they must animate, not freeze.
		if topContext.environment.overCurrentContext { return false }
		switch topContext.environment.behindBehavior {
		case .freeze:
			return true
		case .animate:
			return false
		case .freezeMatching:
			let myID = presentation.transition.transitionID
			let topID = topContext.presentation.transition.transitionID
			return myID == topID
		}
	}
}

extension UIPresentation.Context {

	var changingViewControllers: [UIViewController] {
		direction == .insertion ? viewControllers.toInsert : viewControllers.toRemove
	}

	var topViewControllers: [UIViewController] {
		direction == .insertion
			? Array(viewControllers.to.suffix(1))
			: Array(viewControllers.from.suffix(1))
	}

	var secondViewControllers: [UIViewController] {
		direction == .insertion
			? Array(viewControllers.from.suffix(1))
			: Array(viewControllers.to.suffix(1))
	}

	public var reversed: UIPresentation.Context {
		let reversedControllers = UIPresentation.Context.Controllers(
			fullFrom: viewControllers.fullTo,
			fullTo: viewControllers.fullFrom,
			visibleFrom: viewControllers.to,
			visibleTo: viewControllers.from
		)
		return UIPresentation.Context(
			direction: direction.reversed,
			controller: viewController,
			container: _container,
			controllers: reversedControllers,
			views: views,
			animated: animated,
			animation: animation,
			isInteractive: isInteractive,
			cache: cache,
			updateStatusBar: updateStatusBar,
			presentation: _presentation
		)
	}
}

extension UIPresentation.Context.Controllers {

	var remaining: [UIViewController] {
		to.filter(from.contains)
	}
}
