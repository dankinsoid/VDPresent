import UIKit
import VDTransition

open class UIPresentationController: UIViewController {
  
    public private(set) var viewControllers: [UIViewController] = []
    public var presentation: UIPresentation?
    
    private var cache = UIPresentation.Context.Cache()
    
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
    
    open func set(
        viewControllers newViewControllers: [UIViewController],
        presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        guard newViewControllers != viewControllers else {
            completion?()
            return
        }
        
        let isInsertion = newViewControllers.last.map { !viewControllers.contains($0) } ?? false
        
        makeTransition(
            to: newViewControllers,
            from: viewControllers,
            presentation: presentation ?? self.presentation(for: isInsertion ? newViewControllers.last : viewControllers.last),
            direction: isInsertion ? .insertion : .removal,
            animated: animated,
            completion: completion
        )
    }
}

public extension UIPresentationController {
    
    func show(
        _ viewController: UIViewController,
        presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        if let i = viewControllers.firstIndex(of: viewController) {
            set(
                viewControllers: Array(viewControllers.prefix(through: i)),
                presentation: presentation,
                animated: animated,
                completion: completion
            )
        } else {
            set(
                viewControllers: viewControllers + [viewController],
                presentation: presentation,
                animated: animated,
                completion: completion
            )
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
    
    var visibleViewController: UIViewController? {
        get { viewControllers.last }
        set {
            if let newValue {
                show(newValue)
            }
        }
    }
}

private extension UIPresentationController {
    
    func presentation(
        for viewController: UIViewController?
    ) -> UIPresentation {
        viewController?.defaultPresentation ?? self.presentation ?? .default
    }
}

private extension UIPresentationController {
    
    func makeTransition(
        to toViewControllers: [UIViewController],
        from fromViewControllers: [UIViewController],
        presentation: UIPresentation,
        direction: TransitionDirection,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        let (prepare, animation, completion) = transitionBlocks(
            to: toViewControllers,
            from: fromViewControllers,
            presentation: presentation,
            direction: direction,
            animated: animated,
            completion: completion
        )
        prepare()
        if animated {
            UIView.animate(with: presentation.animation) {
                animation()
            } completion: { isCompleted in
                completion(isCompleted)
            }
        } else {
            animation()
            completion(true)
        }
    }
    
    func transitionBlocks(
        to toViewControllers: [UIViewController],
        from fromViewControllers: [UIViewController],
        presentation: UIPresentation,
        direction: TransitionDirection,
        animated: Bool,
        completion: (() -> Void)?
    ) -> (
        prepare: () -> Void,
        animation: () -> Void,
        completion: (Bool) -> Void
    ) {
        
        var context = UIPresentation.Context(
            direction: direction,
            container: view,
            fromViewControllers: fromViewControllers,
            toViewControllers: toViewControllers,
            animated: animated,
            isInteractive: false,
            cache: cache
        )
        
        let prepare: () -> Void = { [weak self] in
            guard let self else { return }
            
            presentation.transition.update(context: &context, state: .begin)
    
            for toViewController in toViewControllers {
                if toViewController.parent == nil {
                    toViewController.willMove(toParent: self)
                }
                if toViewController.view.superview == nil {
                    self.view.addSubview(toViewController.view)
                    toViewController.view.frame = self.view.bounds
                    toViewController.view.layoutIfNeeded()
                }
                
                if toViewController.parent == nil {
                    self.addChild(toViewController)
                    toViewController.didMove(toParent: self)
                }
            }
            if direction == .removal {
                fromViewControllers.forEach {
                    $0.willMove(toParent: nil)
                }
            }
        }
        
        let animation: () -> Void = { [weak self] in
            guard let self else { return }
            switch direction {
            case .insertion:
                for toViewController in toViewControllers {
                    toViewController.beginAppearanceTransition(true, animated: animated)
                }
                fromViewControllers.last?.beginAppearanceTransition(false, animated: animated)

            case .removal:
                toViewControllers.last?.beginAppearanceTransition(true, animated: animated)
                for fromViewController in fromViewControllers {
                    fromViewController.beginAppearanceTransition(false, animated: animated)
                }
            }
            
            presentation.transition.update(context: &context, state: .change(direction.at(1)))
        }
        
        let completion: (Bool) -> Void = { [weak self] isCompleted in
            guard let self else { return }
            self.viewControllers = toViewControllers
            
            self.afterTransition(presentation: presentation)
            presentation.transition.update(context: &context, state: .end(completed: isCompleted))
            if isCompleted {
                switch direction {
                case .insertion:
                    for toViewController in toViewControllers {
                        toViewController.endAppearanceTransition()
                    }
                    fromViewControllers.last?.endAppearanceTransition()
                    
                case .removal:
                    toViewControllers.last?.endAppearanceTransition()
                    for fromViewController in fromViewControllers {
                        fromViewController.endAppearanceTransition()
                        fromViewController.removeFromParent()
                        fromViewController.view.removeFromSuperview()
                        fromViewController.didMove(toParent: nil)
                    }
                }
            } else {
                
            }
            completion?()
        }
        
        return (prepare, animation, completion)
    }
    
    func afterTransition(
        presentation: UIPresentation
    ) {
        var context = UIPresentation.Context(
            direction: .removal,
            container: view,
            fromViewControllers: viewControllers,
            toViewControllers: viewControllers,
            animated: true,
            isInteractive: true,
            cache: cache
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
                }
                
            case let .change(progress):
                animator?.fractionComplete = progress.progress
                
            case let .end(completed):
                animator?.finishAnimation(at: completed ? .end : .start)
                animator = nil
            }
            presentation.transition.update(context: &context, state: state)
        }
    }
}
