import UIKit
import VDTransition

open class UIPresentationController: UIViewController {
  
    public private(set) var viewControllers: [UIViewController] = []
    public var presentation: UIPresentation?
    
    private var presentations: [UIViewController: UIPresentation] = [:]
    
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
        let present = presentation ?? presentations[vc] ?? vc.defaultPresentation ?? self.presentation ?? .default
        if let i = viewControllers.firstIndex(of: vc) {
            guard viewControllers.last !== vc else {
                completion?()
                return
            }
            makeTransition(
                to: vc,
                presentation: present,
                direction: .removal,
                animated: animated
            ) { [weak self] in
                guard let self else { return }
                self.removeControllers(at: (i + 1)..<self.viewControllers.count)
                completion?()
            }
        } else {
            makeTransition(
                to: vc,
                presentation: present,
                direction: .insertion,
                animated: animated
            ) { [weak self] in
                guard let self else { return }
                self.append(controller: vc, presentation: presentation)
                completion?()
            }
        }
    }
}

public extension UIPresentationController {
    
    static var root: UIPresentationController? {
        UIWindow.key?.rootViewController?
            .selfAndAllPresented.compactMap({ $0 as? UIPresentationController }).first
    }
    
    static var top: UIPresentationController? {
        UIWindow.key?.rootViewController?
            .selfAndAllPresented.compactMap({ $0 as? UIPresentationController }).last?.topOrSelf
    }
    
    var top: UIPresentationController? {
        let lastPresentation = viewControllers.last?.selfAndAllChildren.compactMap { $0 as? UIPresentationController }.last
        let top = lastPresentation?.top ?? lastPresentation
        guard presentedViewController == nil else {
            return allPresented.compactMap({ $0 as? UIPresentationController }).last?.top ?? top
        }
        return top
    }
    
    var topOrSelf: UIPresentationController {
        top ?? self
    }
}

private extension UIPresentationController {
    
    func makeTransition(
        to toViewController: UIViewController,
        presentation: UIPresentation,
        direction: TransitionDirection,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        var context = UIPresentation.Context(
            direction: direction,
            container: view,
            fromController: viewControllers.last,
            toController: toViewController,
            isInteractive: false
        )
        
        presentation.transition.update(context: &context, state: .begin)
        
        if animated {
            UIView.animate(with: presentation.animation) {
                presentation.transition.update(context: &context, state: .change(direction.at(1)))
            } completion: { isCompleted in
                presentation.transition.update(context: &context, state: .end(completed: isCompleted))
                completion?()
            }
        } else {
            presentation.transition.update(context: &context, state: .change(direction.at(1)))
            presentation.transition.update(context: &context, state: .end(completed: true))
            completion?()
        }
    }
    
    func afterTransition(
        presentation: UIPresentation,
        completion: (() -> Void)?
    ) {
        var context = UIPresentation.Context(
            direction: .removal,
            container: view,
            fromController: viewControllers.last,
            toController: nil,
            isInteractive: true
        )
        var animator: UIViewPropertyAnimator?
        presentation.interactivity?.install(context: &context) { state in
            switch state {
            case .begin:
                presentation.transition.update(context: &context, state: .begin)
                animator = UIViewPropertyAnimator()
                animator?.addAnimations {
                    presentation.transition.update(context: &context, state: .change(.removal(.end)))
                }
                animator?.addCompletion { position in
                    completion?()
                }
                
            case let .change(progress):
                animator?.fractionComplete = progress.progress
                
            case let .end(completed):
                animator?.finishAnimation(at: completed ? .end : .start)
            }
            presentation.transition.update(context: &context, state: state)
        }
    }
    
    func removeControllers(at indexes: Range<Int>) {
        viewControllers[indexes].forEach {
            presentations[$0] = nil
        }
        viewControllers.replaceSubrange(indexes, with: [])
    }
    
    func append(controller: UIViewController, presentation: UIPresentation?) {
        presentations[controller] = presentation
        viewControllers.append(controller)
    }
}
