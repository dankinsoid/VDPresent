import UIKit
@_exported import VDTransition

public extension UIViewController {
    
    var defaultPresentation: UIPresentation? {
        get {
            (objc_getAssociatedObject(self, &AssociatedKey.presentation) as? VCPresentation)?.presentation
        }
        set {
            if let holder = objc_getAssociatedObject(self, &AssociatedKey.presentation) as? VCPresentation {
                holder.presentation = newValue
            } else {
                objc_setAssociatedObject(self, &AssociatedKey.presentation, VCPresentation(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    var stackController: UIStackController? {
        (parent as? UIStackController) ?? parent?.stackController
    }
    
    var isShown: Bool {
        get {
            #warning("TODO")
            return isBeingPresented
        }
        set {
            guard newValue != isShown else { return }
            if newValue {
                show()
            } else {
                hide()
            }
        }
    }
    
    @discardableResult
    func show(
        as presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) -> UIStackController {
        let result: UIStackController
        if
            let stackController,
            stackController.presentedViewController == nil
        {
            result = stackController
        } else if
            let stackController = UIStackController.root,
            stackController.presentedViewController == nil
        {
            result = stackController
        } else if let window = UIWindow.root, window.rootViewController == nil {
            result = UIStackController()
            window.rootViewController = result
            window.makeKeyAndVisible()
        } else {
            result = UIStackController()
            result.modalPresentationStyle = .overFullScreen
            result.present(animated: false) {
                result.show(self, presentation: presentation, animated: animated, completion: completion)
            }
            return result
        }
        result.show(self, presentation: presentation, animated: animated, completion: completion)
        return result
    }
    
    func hide(
        as presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard let stackController else {
            dismiss(animated: animated, completion: completion)
            return
        }
				#warning("TODO")
    }
}

private final class VCPresentation {
    
    var presentation: UIPresentation?
    
    init(_ presentation: UIPresentation? = nil) {
        self.presentation = presentation
    }
}

private enum AssociatedKey {
    
    static var presentation = "presentation"
}
