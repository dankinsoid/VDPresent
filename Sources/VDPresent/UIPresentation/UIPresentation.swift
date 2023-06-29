import UIKit
@_exported import VDTransition

public typealias Progress = VDTransition.Progress

public struct UIPresentation {

	public var transition: Transition
	public var interactivity: Interactivity?
	public var animation: UIKitAnimation

	public init(
		transition: Transition,
		interactivity: Interactivity? = nil,
		animation: UIKitAnimation = .default
	) {
		self.transition = transition
		self.interactivity = interactivity
		self.animation = animation
	}

	public static var `default` = UIPresentation.sheet
    
    public var nonInteractive: UIPresentation {
        var result = self
        result.interactivity = nil
        return result
    }
}

public extension UIPresentation {

	struct Context {

		public let direction: TransitionDirection
        public var fromViewControllers: [UIViewController] { _fromViewControllers.compactMap(\.value) }
        public var toViewControllers: [UIViewController] { _toViewControllers.compactMap(\.value) }
		public let animated: Bool
		public let isInteractive: Bool
		public let cache: Cache
        
        private let _fromViewControllers: [Weak<UIViewController>]
        private let _toViewControllers: [Weak<UIViewController>]
        private let views: (UIViewController) -> UIView
        private let container: (UIViewController) -> UIStackControllerContainer

		public init(
			direction: TransitionDirection,
			container: @escaping (UIViewController) -> UIStackControllerContainer,
			fromViewControllers: [UIViewController],
			toViewControllers: [UIViewController],
            views: @escaping (UIViewController) -> UIView,
			animated: Bool,
			isInteractive: Bool,
			cache: Cache
        ) {
            self.direction = direction
            self.container = container
            self._fromViewControllers = fromViewControllers.map { Weak($0) }
            self._toViewControllers = toViewControllers.map { Weak($0) }
            self.views = views
            self.animated = animated
            self.isInteractive = isInteractive
            self.cache = cache
        }
        
        public func container(for controller: UIViewController) -> UIStackControllerContainer {
            container(controller)
        }
        
        public func view(for controller: UIViewController) -> UIView {
            views(controller)
        }
        
		public func viewControllers(_ key: UITransitionContextViewControllerKey) -> [UIViewController] {
			switch key {
			case .from: return fromViewControllers
			case .to: return toViewControllers
			default: return []
			}
		}
	}

	struct Interactivity {

		private let installer: (Context, @escaping (Context, State) -> Policy) -> Void
        private let uninstaller: (Context) -> Void

		public init(
            installer: @escaping (Context, @escaping (Context, State) -> Policy) -> Void,
            uninstaller: @escaping (Context) -> Void
        ) {
			self.installer = installer
            self.uninstaller = uninstaller
		}

		public func install(context: Context, observer: @escaping (Context, State) -> Policy) {
			installer(context, observer)
		}
        
        public func uninstall(context: Context) {
            uninstaller(context)
        }
        
        public enum Policy {
            case allow, prevent
        }
	}

	struct Transition {

		private var updater: (Context, State) -> Void

		public init(
			updater: @escaping (Context, State) -> Void
		) {
			self.updater = updater
		}

		public func update(context: Context, state: State) {
			updater(context, state)
		}
	}

	enum State: Equatable {

		case begin
		case change(Progress)
        case end(completed: Bool, animation: UIKitAnimation? = nil)
	}
}

public extension UIPresentation.Context {

	var viewControllersToRemove: [UIViewController] {
		fromViewControllers.filter { !toViewControllers.contains($0) }
	}

	var viewControllersToInsert: [UIViewController] {
		toViewControllers.filter { !fromViewControllers.contains($0) }
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
