import UIKit
import VDTransition

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
}

public extension UIPresentation {

	struct Context {

		public var direction: TransitionDirection
		public var container: UIView
		public var fromViewControllers: [UIViewController]
		public var toViewControllers: [UIViewController]
		public var animated: Bool
		public var isInteractive: Bool
		public var cache: Cache

		public init(
			direction: TransitionDirection,
			container: UIView,
			fromViewControllers: [UIViewController],
			toViewControllers: [UIViewController],
			animated: Bool,
			isInteractive: Bool,
			cache: Cache
		) {
			self.direction = direction
			self.container = container
			self.fromViewControllers = fromViewControllers
			self.toViewControllers = toViewControllers
			self.animated = animated
			self.isInteractive = isInteractive
			self.cache = cache
		}

		public func viewController(_ key: UITransitionContextViewControllerKey) -> [UIViewController] {
			switch key {
			case .from: return fromViewControllers
			case .to: return toViewControllers
			default: return []
			}
		}
	}

	struct Interactivity {

		private let installer: (inout Context, @escaping (State) -> Void) -> Void

		public init(installer: @escaping (inout Context, @escaping (State) -> Void) -> Void) {
			self.installer = installer
		}

		public func install(context: inout Context, observer: @escaping (State) -> Void) {
			installer(&context, observer)
		}
	}

	struct Transition {

		private var updater: (inout Context, State) -> Void

		public init(
			updater: @escaping (inout Context, State) -> Void
		) {
			self.updater = updater
		}

		public func update(context: inout Context, state: State) {
			updater(&context, state)
		}
	}

	enum State: Hashable {

		case begin
		case change(Progress)
		case end(completed: Bool)
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

	struct Cache {

		private var values: [PartialKeyPath<UIPresentation.Context>: Any] = [:]

		public subscript<T>(_ keyPath: KeyPath<UIPresentation.Context, T>) -> T? {
			get { values[keyPath] as? T }
			set { values[keyPath] = newValue }
		}

		public init() {}
	}
}
