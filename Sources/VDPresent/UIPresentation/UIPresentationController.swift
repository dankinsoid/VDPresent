import UIKit
import VDTransition

open class UIPresentationController: UIViewController {
  
    public private(set) var viewControllers: [UIViewController] = []
    public var presentation: UIPresentation?
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationStyle = .overFullScreen
        view.backgroundColor = .clear
    }
    
    override open func show(_ vc: UIViewController, sender: Any?) {
        show(vc)
    }
    
    override open func targetViewController(forAction action: Selector, sender: Any?) -> UIViewController? {
        super.targetViewController(forAction: action, sender: sender)
    }
    
    open func show(
        _ vc: UIViewController,
        presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        if viewControllers.contains(vc) {
            guard viewControllers.last !== vc else {
                completion?()
                return
            }
            
        } else {
            viewControllers.append(vc)
        }
    }
}

public extension UIPresentationController {
    
    static var root: UIPresentationController? {
        UIWindow.key?.rootViewController?
            .selfAndAllPresented.compactMap({ $0 as? UIPresentationController }).first
    }
    
    static var top: UIPresentationController? {
        root?.topOrSelf
    }
    
    var top: UIPresentationController? {
        let lastPresentation = viewControllers.last?.selfAndAllChildren.compactMap { $0 as? UIPresentationController }.last
        return lastPresentation?.top ?? lastPresentation
    }
    
    var topOrSelf: UIPresentationController {
        top ?? self
    }
}

private extension UIPresentationController {
    
    func makeTransition(
        presentation: UIPresentation,
        direction: TransitionDirection,
        completion: (() -> Void)?
    ) {
        
    }
}
