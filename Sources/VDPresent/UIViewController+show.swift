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
    
    var presentationController: UIPresentationController? {
        (parent as? UIPresentationController) ?? parent?.presentationController
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
    ) -> UIPresentationController {
        let result: UIPresentationController
        if
            let presentationController,
            presentationController.presentedViewController == nil
        {
            result = presentationController
        } else if
            let presentationController = UIPresentationController.root,
            presentationController.presentedViewController == nil
        {
            result = presentationController
        } else if let window = UIWindow.root, window.rootViewController == nil {
            result = UIPresentationController()
            window.rootViewController = result
            window.makeKeyAndVisible()
        } else {
            result = UIPresentationController()
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
        guard let presentationController else {
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
