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
    
    struct Context: Hashable {
        
        public var direction: TransitionDirection
        public var container: UIView
        public var fromController: UIViewController?
        public var toController: UIViewController?
        public var isInteractive: Bool
        
        public init(
            direction: TransitionDirection,
            container: UIView,
            fromController: UIViewController?,
            toController: UIViewController?,
            isInteractive: Bool
        ) {
            self.direction = direction
            self.container = container
            self.fromController = fromController
            self.toController = toController
            self.isInteractive = isInteractive
        }
        
        public func viewController(_ key: UITransitionContextViewControllerKey) -> UIViewController? {
            switch key {
            case .from: return fromController
            case .to: return toController
            default: return nil
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

public extension UIPresentation.Transition {
    
    init(
        content: UITransition<UIView>,
        background: UITransition<UIView>,
        applyTransitionOnBothControllers: Bool = false,
        prepare: ((UIPresentation.Context) -> Void)? = nil,
        completion: ((UIPresentation.Context, Bool) -> Void)? = nil
    ) {
        var transitions: [KeyPath<UIPresentation.Context, UIView?>: UITransition<UIView>] = [
            \.container.optional: background
        ]
        self.init { context, state in
            switch state {
            case .begin:
                transitions.forEach {
                    if let view = context[keyPath: $0.key] {
                        transitions[$0.key]?.beforeTransition(view: view)
                    }
                }
                prepare?(context)
                
            case let .change(progress):
                transitions.forEach {
                    if let view = context[keyPath: $0.key] {
                        $0.value.update(progress: progress, view: view)
                    }
                }
                break
                
            case let .end(completed):
                transitions.forEach {
                    if let view = context[keyPath: $0.key] {
                        $0.value.setInitialState(view: view)
                    }
                }
                completion?(context, completed)
            }
        }
    }
}
