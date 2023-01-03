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
}

public extension UIPresentation {
    
    struct Context: Hashable {
        
        public var direction: TransitionDirection
        public var container: UIView
        
        public init(
            direction: TransitionDirection,
            container: UIView
        ) {
            self.direction = direction
            self.container = container
        }
    }
    
    struct Interactivity {
        
        private let installer: (Context, @escaping (State) -> Void) -> Void
        
        public init(installer: @escaping (Context, @escaping (State) -> Void) -> Void) {
            self.installer = installer
        }
        
        public func install(context: Context, observer: @escaping (State) -> Void) {
            installer(context, observer)
        }
    }
    
    struct Transition {
        
        private var updater: (Context, State) -> Void
        
        public init(
            updater: @escaping (Context, State) -> Void
        ) {
            self.updater = updater
        }
        
        public func update(context: Context, progress: State) {
            updater(context, progress)
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
        prepare: ((UIPresentation.Context) -> Void)? = nil,
        completion: ((UIPresentation.Context, Bool) -> Void)? = nil
    ) {
        var contentTransition = content
        var backgroundTransition = background
        self.init { context, state in
            switch state {
            case .begin:
                contentTransition.beforeTransition(view: <#T##UIView#>)
                prepare?(context)
                
            case let .change(progress):
                contentTransition.update(progress: progress, view: <#T##UIView#>)
                break
                
            case let .end(completed):
                contentTransition.setInitialState(view: <#T##UIView#>)
                completion?(context, completed)
            }
        }
    }
}
