import UIKit
import VDTransition

open class UIPresentationController: UIViewController {
  
    public private(set) var viewControllers: [UIViewController] = []
    
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

private extension UIPresentationController {
    
    func makeTransition(
        presentation: UIPresentation,
        direction: TransitionDirection,
        completion: (() -> Void)?
    ) {
        
    }
}
