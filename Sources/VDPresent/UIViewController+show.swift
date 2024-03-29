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
            guard viewIfLoaded?.window != nil else { return false }
            if let stackController {
                guard let top = stackController.topViewController else {
                    return false
                }
                return isDescendant(of: top) && stackController.isShown
            } else if let root = UIWindow.root?.rootViewController {
                if let presented = root.allPresented.last {
                    return isDescendant(of: presented)
                } else {
                    return isDescendant(of: root)
                }
            } else {
                return false
            }
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
				result.show(self, as: presentation, animated: animated, completion: completion)
			}
			return result
		}
        if result.stackController != nil {
            var isCompleted = false
            result.show(self, as: presentation, animated: animated) {
                guard isCompleted else {
                    isCompleted = true
                    return
                }
                completion?()
            }
            result.show(animated: animated) {
                guard isCompleted else {
                    isCompleted = true
                    return
                }
                completion?()
            }
        } else {
            result.show(self, as: presentation, animated: animated, completion: completion)
        }
		return result
	}

	func hide(
		as presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (() -> Void)? = nil
	) {
		guard let stackController else {
            guard UIWindow.root?.rootViewController !== self else {
                completion?()
                return
            }
            if presentedViewController != nil, let presentingViewController {
                presentingViewController.dismiss(animated: animated, completion: completion)
            } else {
                dismiss(animated: animated, completion: completion)
            }
			return
		}
        guard let index = stackController.viewControllers.firstIndex(where: isDescendant) else {
            completion?()
            return
        }
        stackController.set(
            viewControllers: Array(stackController.viewControllers.prefix(upTo: index)),
            animated: animated
        ) {
            if index == 0, stackController !== UIWindow.root?.rootViewController {
                stackController.hide(animated: false, completion: completion)
            } else {
                completion?()
            }
        }
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
