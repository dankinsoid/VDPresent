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
            update(context: &context, progress: state)
            context
        }
    }
}
