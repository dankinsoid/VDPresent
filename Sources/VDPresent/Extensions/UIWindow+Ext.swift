import UIKit

extension UIWindow {
    
    static var key: UIWindow? {
        UIApplication.shared.windows.first(where: \.isKeyWindow)
    }
}
