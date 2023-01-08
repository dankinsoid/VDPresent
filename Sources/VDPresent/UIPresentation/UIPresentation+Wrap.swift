import UIKit

public extension UIPresentation {
    
    func wrap(_ wrapper: @escaping (UIViewController) -> UIViewController) -> UIPresentation {
        var result = self
        result.transition = transition.wrap(wrapper)
        return result
    }
}

public extension UIPresentation.Transition {
    
    func wrap(_ wrapper: @escaping (UIViewController) -> UIViewController) -> UIPresentation.Transition {
        UIPresentation.Transition { context, state in
            if state == .begin {
                context.toViewControllers = context.toViewControllers.map(wrapper)
            }
            update(context: &context, state: state)
        }
    }
}
