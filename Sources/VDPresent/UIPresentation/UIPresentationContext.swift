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

		public init(
			direction: TransitionDirection,
			controller: UIViewController,
			container: @escaping (UIViewController) -> UIStackControllerCanvas,
			fromViewControllers: [UIViewController],
			toViewControllers: [UIViewController],
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
			viewControllers = Controllers(
				fromViewControllers: fromViewControllers,
				toViewControllers: toViewControllers
			)
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

	struct Controllers {

		public var from: [UIViewController] {
			get { _fromViewControllers.compactMap(\.value) }
			set { _fromViewControllers = newValue.map { Weak($0) } }
		}

		public var to: [UIViewController] {
			get { _toViewControllers.compactMap(\.value) }
			set { _toViewControllers = newValue.map { Weak($0) } }
		}

		private var _fromViewControllers: [Weak<UIViewController>]
		private var _toViewControllers: [Weak<UIViewController>]

		public init(
			fromViewControllers: [UIViewController],
			toViewControllers: [UIViewController]
		) {
			_fromViewControllers = fromViewControllers.map { Weak($0) }
			_toViewControllers = toViewControllers.map { Weak($0) }
		}

		public subscript(_ key: UITransitionContextViewControllerKey) -> [UIViewController] {
			switch key {
			case .from: return from
			case .to: return to
			default: return []
			}
		}

		/// Returns a new `Controllers` containing only the visible slice of each stack.
		///
		/// Walks each stack top-down. Includes every controller until one level
		/// below the first `overCurrentContext == false` (opaque) controller.
		/// The opaque controller and one below it are included because
		/// recessTransition from the opaque one animates the view below.
		/// @ai-generated(paired)
		func visible(
			_ presentation: (UIViewController) -> UIPresentation
		) -> Controllers {
			Controllers(
				fromViewControllers: Self.visibleSlice(of: from, presentation: presentation),
				toViewControllers: Self.visibleSlice(of: to, presentation: presentation)
			)
		}

		private static func visibleSlice(
			of stack: [UIViewController],
			presentation: (UIViewController) -> UIPresentation
		) -> [UIViewController] {
			guard !stack.isEmpty else { return [] }
			// Walk backward from top until we find an opaque controller
			// (one without overCurrentContext). That controller and everything
			// above it form the visible slice.
			for i in stride(from: stack.count - 1, through: 0, by: -1) {
				if !presentation(stack[i]).environment.overCurrentContext {
					return Array(stack[i...])
				}
			}
			// All controllers are overCurrentContext — entire stack is visible.
			return stack
		}
	}
}

public extension UIPresentation.Context.Controllers {

	var toRemove: [UIViewController] {
		from.filter { !to.contains($0) }
	}

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

	var isTopTheSame: Bool {
		from.last === to.last
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

	/// Visible slice of the stack, set by UIStackController before the animation pipeline.
	/// Used by `applyBackEffects` so barriers from non-visible departing controllers
	/// don't block recess propagation to re-entering controllers.
	var visibleViewControllers: Controllers {
		get { cache[\.visibleViewControllers] ?? viewControllers }
		nonmutating set { cache[\.visibleViewControllers] = newValue }
	}

	var isChangingController: Bool {
		!viewControllers.to.contains(viewController) || !viewControllers.from.contains(viewController)
	}

	var isRemainingController: Bool {
		!isChangingController
	}

	/// Whether there is a barrier controller above this one in the visible stack.
	/// @ai-generated(solo)
	var hasFrontBarrier: Bool {
		let allControllers = visibleViewControllers.all(direction)
		guard let myIndex = allControllers.firstIndex(of: viewController) else { return false }
		return allControllers[(myIndex + 1)...].contains { self.for($0).environment.backEffectBarrier }
	}

	var isTopController: Bool {
		topViewControllers.contains(viewController)
	}

	var isSecondController: Bool {
		secondViewControllers.contains(viewController)
	}

	var needHide: Bool {
		let all = viewControllers[.to]
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
		guard !isTopController else { return false }
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
		UIPresentation.Context(
			direction: direction.reversed,
			controller: viewController,
			container: _container,
			fromViewControllers: viewControllers.to,
			toViewControllers: viewControllers.from,
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
