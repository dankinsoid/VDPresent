import UIKit

public extension UIPresentation.Transition {
    
    func wrap(_ wrapper: @escaping (UIViewController) -> UIViewController) -> UIPresentation.Transition {
        UIPresentation.Transition { context, state in
            
        }
    }
}

public extension UIPresentation {
    
    func wrap(_ wrapper: @escaping (UIViewController) -> UIViewController) -> UIPresentation {
        UIPresentation(
            transition: transition.wrap(wrapper),
            interactivity: interactivity,
            animation: animation
        )
    }
}
