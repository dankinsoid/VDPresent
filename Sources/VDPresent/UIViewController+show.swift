import UIKit
@_exported import VDTransition

public extension UIViewController {
    
    var isShown: Bool {
        get { isBeingPresented }
        set {  }
    }
    
    func show(
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        
    }
    
    func hide(
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        
    }
}
