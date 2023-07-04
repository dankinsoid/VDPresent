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
            UIPresentation.Transition { _, _ in }
        }
        
		private var updater: (Context, State) -> Void
        public var environment: UIPresentation.Environment

		public init(
			updater: @escaping (Context, State) -> Void,
            environment: UIPresentation.Environment = UIPresentation.Environment()
		) {
			self.updater = updater
            self.environment = environment
		}

		public func update(context: Context, state: State) {
			updater(context, state)
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
        
        public func with(
            updater newUpdater: @escaping (Context, State) -> Void
        ) -> UIPresentation.Transition {
            var result = self
            result.updater = { [updater] in
                updater($0, $1)
                newUpdater($0, $1)
            }
            return result
        }
	}

	enum State: Equatable {

		case begin
        case change(Progress.Edge)
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
    }
}
