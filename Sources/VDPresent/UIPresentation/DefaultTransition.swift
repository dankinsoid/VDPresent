import UIKit
import VDTransition

public extension UIPresentation.Transition {
    
    init(
        content: UITransition<UIView>,
        background: UITransition<UIView>,
        applyTransitionOnBothControllers: Bool = false,
        prepare: ((inout UIPresentation.Context) -> Void)? = nil,
        completion: ((UIPresentation.Context, Bool) -> Void)? = nil
    ) {
        var background: UIView?
        let backgroundID = "BackgroundView"
        
        self.init { context, state in
            switch state {
            case .begin:
                prepare?(&context)
                
                context.transitions.forEach {
                    if let view = $0.key {
                        $0.value.setInitialState(view: view)
                    }
                }
                
                context.transitions = [:]
                
                context.toViewControllers.forEach {
                    context.transitions[$0.view] = content
                }
                if applyTransitionOnBothControllers {
                    context.fromViewControllers.forEach {
                        context.transitions[$0.view] = content.inverted
                    }
                }
                
                context.transitions.forEach {
                    if let view = $0.key {
                        context.transitions[$0.key]?.beforeTransition(view: view)
                    }
                }
                
            case let .change(progress):
                context.transitions.forEach {
                    if let view = $0.key {
                        $0.value.update(progress: progress, view: view)
                    }
                }
                
            case let .end(completed):
                context.transitions.forEach {
                    if let view = $0.key {
                        $0.value.setInitialState(view: view)
                    }
                }
                context.transitions = [:]
                completion?(context, completed)
            }
        }
    }
}

private extension UIPresentation.Context {
    
    var transitions: [UIView?: UITransition<UIView>] {
        get {
            cache[\.transitions] ?? [:]
        }
        set {
            cache[\.transitions] = newValue
        }
    }
    
    var constraints: [NSLayoutConstraint] {
        get {
            cache[\.constraints] ?? []
        }
        set {
            cache[\.constraints] = newValue
        }
    }
}
