import UIKit
@_exported import VDTransition

public typealias Progress = VDTransition.Progress

public struct UIPresentation {

	public var transition: Transition
	public var interactivity: Interactivity?
	public var animation: UIKitAnimation
    public var environment: Environment { transition.environment }

	public init(
        transition: Transition = .default(),
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
        result.transition = transition.environment(keyPath, value)
        return result
    }
    
    public func transformEnvironment<T>(
        _ keyPath: WritableKeyPath<UIPresentation.Environment, T>,
        _ value: (T) -> T
    ) -> UIPresentation {
        var result = self
        result.transition = transition.transformEnvironment(keyPath, value)
        return result
    }
}

public extension UIPresentation {

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
        
        public static var identity: UIPresentation.Transition {
            UIPresentation.Transition(prepare: { _ in }, animate: { _, _ in }, completion: { _, _ in })
        }
        
        private var _prepare: (Context) -> Void
		private var _animate: (Context, @escaping (State) -> Void) -> Void
        private var _completion: (Context, Bool) -> Void
        public var environment: UIPresentation.Environment

		public init(
            environment: UIPresentation.Environment = UIPresentation.Environment(),
            prepare: @escaping (Context) -> Void,
            animate: @escaping (Context, @escaping (State) -> Void) -> Void,
            completion: @escaping (Context, Bool) -> Void
		) {
			self._prepare = prepare
            self._animate = animate
            self._completion = completion
            self.environment = environment
		}

        public func prepare(context: Context) {
            _prepare(context)
        }
        
		public func animate(context: Context, update: @escaping (State) -> Void) {
			_animate(context, update)
		}
        
        public func completion(context: Context, completed: Bool) {
            _completion(context, completed)
        }
        
        public func environment<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>, _ value: T) -> UIPresentation.Transition {
            var result = self
            result.environment[keyPath: keyPath] = value
            return result
        }
        
        public func transformEnvironment<T>(
            _ keyPath: WritableKeyPath<UIPresentation.Environment, T>,
            _ value: (T) -> T
        ) -> UIPresentation.Transition {
            var result = self
            result.environment[keyPath: keyPath] = value(result.environment[keyPath: keyPath])
            return result
        }
        
//        public func with(
//            updater newUpdater: @escaping (Context, State) -> Void
//        ) -> UIPresentation.Transition {
//            var result = self
//            result._prepare = { [_prepare] context, update in
//                _prepare(context) {
//                    update($0)
//                    newUpdater(context, $0)
//                }
//            }
//            return result
//        }
	}

	enum State {

        case begin
		case prepareInteractive((Interactivity.State) -> Void)
        case end(completed: Bool)
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
        
        public func with<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>, _ value: T?) -> UIPresentation.Environment {
            var result = self
            result[keyPath] = value
            return result
        }
    }
}
