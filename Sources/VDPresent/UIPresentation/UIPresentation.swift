import UIKit
@_exported import VDTransition

public typealias Progress = VDTransition.Progress

public struct UIPresentation {

	public var transition: Transition
	public var interactivity: Interactivity?
	public var animation: UIKitAnimation
    public var environment: UIPresentation.Environment

	public init(
        transition: Transition = .default(),
		interactivity: Interactivity? = nil,
		animation: UIKitAnimation = .default,
        environment: UIPresentation.Environment = UIPresentation.Environment()
	) {
		self.transition = transition
		self.interactivity = interactivity
		self.animation = animation
        self.environment = environment
	}

	public static var `default` = UIPresentation.sheet
    
    public var nonInteractive: UIPresentation {
        var result = self
        result.interactivity = nil
        return result
    }
    
    public func with(animation: UIKitAnimation) -> UIPresentation {
        var result = self
        result.animation = animation
        return result
    }
    
    public func with(interactivity: Interactivity?) -> UIPresentation {
        var result = self
        result.interactivity = interactivity
        return result
    }
    
    public func environment<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>, _ value: T) -> UIPresentation {
        var result = self
        result.environment[keyPath: keyPath] = value
        return result
    }
    
    public func transformEnvironment<T>(
        _ keyPath: WritableKeyPath<UIPresentation.Environment, T>,
        _ value: (T) -> T
    ) -> UIPresentation {
        var result = self
        result.environment[keyPath: keyPath] = value(result.environment[keyPath: keyPath])
        return result
    }
}

public extension UIPresentation {

	struct Context {

        public var viewController: UIViewController {
            _controller ?? UIViewController()
        }
        public var view: UIView {
            view(for: viewController)
        }
        public var container: UIStackControllerContainer {
            container(for: viewController)
        }
		public let animated: Bool
		public let isInteractive: Bool
		public let cache: Cache
        public let animation: UIKitAnimation
        public let viewControllers: Controllers
        
        public var direction: TransitionDirection {
            if viewControllers.to.last === viewController || !viewControllers.from.contains(viewController) {
                return .insertion
            } else {
                return .removal
            }
        }
        
        public var environment: UIPresentation.Environment {
            _environment(viewController)
        }
        
        private weak var _controller: UIViewController?
        private let views: (UIViewController) -> UIView
        private let _container: (UIViewController) -> UIStackControllerContainer
        private let _environment: (UIViewController) -> UIPresentation.Environment
        private let _updateStatusBar: (UIStatusBarStyle, UIStatusBarAnimation) -> Void

		public init(
            controller: UIViewController,
			container: @escaping (UIViewController) -> UIStackControllerContainer,
			fromViewControllers: [UIViewController],
			toViewControllers: [UIViewController],
            views: @escaping (UIViewController) -> UIView,
			animated: Bool,
            animation: UIKitAnimation,
			isInteractive: Bool,
			cache: Cache,
            updateStatusBar: @escaping (UIStatusBarStyle, UIStatusBarAnimation) -> Void,
            environment: @escaping (UIViewController) -> UIPresentation.Environment
        ) {
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
        
        public func environment(for controller: UIViewController) -> UIPresentation.Environment {
            _environment(controller)
        }
        
        public func container(for controller: UIViewController) -> UIStackControllerContainer {
            _container(controller)
        }
        
        public func updateStatusBar(style: UIStatusBarStyle, animation: UIStatusBarAnimation = .fade) {
            _updateStatusBar(style, animation)
        }
        
        public func view(for controller: UIViewController) -> UIView {
            views(controller)
        }
        
        public func `for`(controller: UIViewController) -> Self {
            var result = self
            result._controller = controller
            return result
        }
        
        public struct Controllers {
            
            public var from: [UIViewController] { _fromViewControllers.compactMap(\.value) }
            public var to: [UIViewController] { _toViewControllers.compactMap(\.value) }
            public var direction: TransitionDirection {
                to.last.map { !from.contains($0) } ?? false
                    ? .insertion
                    : .removal
            }
            private let _fromViewControllers: [Weak<UIViewController>]
            private let _toViewControllers: [Weak<UIViewController>]
            
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
        
        public enum State: Equatable {
            
            case begin
            case change(Progress)
            case end(completed: Bool, after: Double)
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
        case change(Progress.Edge)
        case end(completed: Bool)
	}
}

public extension UIPresentation.Context.Controllers {

	var toRemove: [UIViewController] {
		from.filter { !to.contains($0) }
	}

	var toInsert: [UIViewController] {
		to.filter { !from.contains($0) }
	}
    
    var all: [UIViewController] {
        guard !from.isEmpty else { return to }
        guard !to.isEmpty else { return from }
        let prefix = from.dropLast().filter { !to.contains($0) } + to.dropLast()
        let suffix = from.suffix(1) + to.suffix(1).filter { $0 !== from.last }
        return direction == .insertion
        ? prefix + suffix
        : prefix + suffix.reversed()
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

public extension UIPresentation {
    
    struct Environment {
        
        private var values: [PartialKeyPath<UIPresentation.Environment>: Any] = [:]
        
        public subscript<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>) -> T? {
            get { values[keyPath] as? T }
            set { values[keyPath] = newValue }
        }
        
        public init() {}
    }
}
