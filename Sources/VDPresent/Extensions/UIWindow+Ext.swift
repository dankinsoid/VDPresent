import UIKit

extension UIWindow {
    
    static var key: UIWindow? {
        UIApplication.shared.windows.first(where: \.isKeyWindow)
    }
    
    static var root: UIWindow? {
        (UIApplication.shared.delegate?.window ?? nil) ??
            .key ??
        UIApplication.shared.windows.first
    }
}
