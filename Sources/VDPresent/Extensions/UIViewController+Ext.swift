import UIKit

public extension UIViewController {
    
    func present(animated: Bool = true, completion: (() -> Void)? = nil) {
        UIWindow.key?.rootViewController?.vcForPresent
            .present(self, animated: animated, completion: completion)
    }
}

extension UIViewController {
    
    var vcForPresent: UIViewController {
        presentedViewController?.vcForPresent ?? self
    }
}
