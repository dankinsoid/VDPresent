import UIKit

public extension UIPresentation {
    
    func wrap(_ wrapper: @escaping (UIViewController) -> UIViewController) -> UIPresentation {
        var result = self
        result.modifier = { [modifier] in
            wrapper(modifier($0))
        }
        return result
    }
}
