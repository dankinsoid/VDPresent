import UIKit

public extension UIPresentation {
    
    struct Context {
        
        public var viewController: UIViewController {
            _controller ?? UIViewController()
        }
        public var view: UIStackViewWrapper {
            views(viewController)
        }
        public var container: UIStackControllerContainer {
            _container(viewController)
        }
        public var animated: Bool
        public var isInteractive: Bool
        public var cache: Cache
        public var animation: UIKitAnimation
        public var viewControllers: Controllers
        public var direction: TransitionDirection
        
        public var environment: UIPresentation.Environment {
            _environment(viewController)
        }
        
        private weak var _controller: UIViewController?
        private let views: (UIViewController) -> UIStackViewWrapper
        private let _container: (UIViewController) -> UIStackControllerContainer
        private let _environment: (UIViewController) -> UIPresentation.Environment
        private let _updateStatusBar: (UIStatusBarStyle, UIStatusBarAnimation) -> Void
        
        public init(
            direction: TransitionDirection,
            controller: UIViewController,
            container: @escaping (UIViewController) -> UIStackControllerContainer,
            fromViewControllers: [UIViewController],
            toViewControllers: [UIViewController],
            views: @escaping (UIViewController) -> UIStackViewWrapper,
            animated: Bool,
            animation: UIKitAnimation,
            isInteractive: Bool,
            cache: Cache,
            updateStatusBar: @escaping (UIStatusBarStyle, UIStatusBarAnimation) -> Void,
            environment: @escaping (UIViewController) -> UIPresentation.Environment
        ) {
            self.direction = direction
            self._controller = controller
            self._container = container
            self.viewControllers = Controllers(
                fromViewControllers: fromViewControllers,
                toViewControllers: toViewControllers
            )
            self.views = views
            self.animated = animated
            self.isInteractive = isInteractive
            self.cache = cache
            self._updateStatusBar = updateStatusBar
            self._environment = environment
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

extension UIPresentation.Context {
    
    public struct Controllers {
        
        public var from: [UIViewController] {
            get { _fromViewControllers.compactMap(\.value) }
            set { _fromViewControllers = newValue.map { Weak($0) } }
        }
        public var to: [UIViewController] {
            get { _toViewControllers.compactMap(\.value) }
            set {  _toViewControllers = newValue.map { Weak($0) } }
        }
        private var _fromViewControllers: [Weak<UIViewController>]
        private var _toViewControllers: [Weak<UIViewController>]
        
        public init(
            fromViewControllers: [UIViewController],
            toViewControllers: [UIViewController]
        ) {
            self._fromViewControllers = fromViewControllers.map { Weak($0) }
            self._toViewControllers = toViewControllers.map { Weak($0) }
        }
        
        public subscript(_ key: UITransitionContextViewControllerKey) -> [UIViewController] {
            switch key {
            case .from: return from
            case .to: return to
            default: return []
            }
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
	// @ai-generated(guided)
	func all(_ direction: TransitionDirection) -> [UIViewController] {
		guard !from.isEmpty else { return to }
		guard !to.isEmpty else { return from }

		// --- Index maps: controller → position. O(n + m) ---
		var fromIndex: [ObjectIdentifier: Int] = Dictionary(minimumCapacity: from.count)
		for (i, vc) in from.enumerated() { fromIndex[ObjectIdentifier(vc)] = i }
		let toSet = Set(to.map { ObjectIdentifier($0) })

		// --- Common prefix — fast path for push / pop ---
		var prefixEnd = 0
		while prefixEnd < from.count && prefixEnd < to.count
				&& from[prefixEnd] === to[prefixEnd] {
			prefixEnd += 1
		}
		var result = Array(to[..<prefixEnd])

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
			for j in (fi + 1)..<from.count {
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
        let all = viewControllers[.to]
        guard let j = all.firstIndex(of: viewController) else { return true }
        for (index, vc) in all.enumerated().reversed() {
            if index == j {
                return false
            }
            let context = self.for(vc)
            if !context.environment.overCurrentContext(context) {
                return true
            }
        }
        return false
    }
    
    var needAnimate: Bool {
        isTopController && !viewControllers.isTopTheSame || isChangingController && !needHide
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
            environment: _environment
        )
    }
}

extension UIPresentation.Context.Controllers {
    
    var remaining: [UIViewController] {
        to.filter(from.contains)
    }
}
