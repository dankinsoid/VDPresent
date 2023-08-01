import UIKit

public extension UIStackController {
    
    static var root: UIStackController? {
        UIWindow.key?.rootViewController?
            .selfAndAllPresented.compactMap { $0 as? UIStackController }.first
    }
    
    static var top: UIStackController? {
        UIWindow.key?.rootViewController?
            .selfAndAllPresented.compactMap { $0 as? UIStackController }.last?.topStackControllerOrSelf
    }
    
    var topStackController: UIStackController? {
        let lastPresentation = viewControllers.last?.selfAndAllChildren.compactMap { $0 as? UIStackController }.last
        let top = lastPresentation?.topStackController ?? lastPresentation
        guard presentedViewController == nil else {
            return allPresented.compactMap { $0 as? UIStackController }.last?.topStackController ?? top
        }
        return top
    }
    
    var topStackControllerOrSelf: UIStackController {
        topStackController ?? self
    }
    
    var topViewController: UIViewController? {
        get { viewControllers.last }
        set {
            if let newValue {
                show(newValue)
            } else {
                hide(viewControllers.count)
            }
        }
    }
}

public extension UIStackController {
    
    func show(
        _ viewController: UIViewController,
        as presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        if let i = viewControllers.firstIndex(where: viewController.isDescendant) {
            if let child = viewController.stackController, child !== self {
                child.show(as: presentation, animated: animated, completion: completion)
            } else {
                set(
                    viewControllers: Array(viewControllers.prefix(through: i)),
                    as: presentation,
                    animated: animated,
                    completion: completion
                )
            }
        } else {
            set(
                viewControllers: viewControllers + [viewController],
                as: presentation,
                animated: animated,
                completion: completion
            )
        }
    }
    
    func hide(
        _ count: Int = 1,
        as presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        set(
            viewControllers: Array(viewControllers.dropLast(count)),
            as: presentation,
            animated: animated,
            completion: completion
        )
    }
}
