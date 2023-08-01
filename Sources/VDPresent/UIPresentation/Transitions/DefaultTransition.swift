import UIKit
import VDTransition

public extension UIPresentation.Transition {

	static func `default`(
        transition: UIViewTransition = .identity,
        moveToBackTransition: UIViewTransition = .identity,
        layout: ContentLayout = .fill,
        overCurrentContext: Bool = false,
		prepare: ((UIPresentation.Context) -> Void)? = nil,
        animation: ((UIPresentation.Context, Progress) -> Void)? = nil,
		completion: ((UIPresentation.Context, Bool) -> Void)? = nil
	) -> UIPresentation.Transition {
        .uiViewAnimate { context in
            let view = context.view
            if context.isTopController || !context.needHide {
                context.container.isHidden = false
            }
            
            let needAnimate = context.needAnimate
            
            let currentTransition = context.insertionTransitions[view]
            if needAnimate {
                context.insertionTransitions[view] = context.environment.contentTransition(context)
            } else if context.insertionTransitions[view] != nil {
                context.insertionTransitions[view] = context.environment.contentTransition(context).constant(at: .insertion(1))
            }
            context.insertionTransitions[view]?.beforeTransitionIfNeeded(view: view, current: currentTransition)
            
            if context.isTopController {
                let array = context.environment.overCurrentContext(context)
                  ? context.viewControllers.from
                  : context.viewControllers.remaining
                array
                    .filter { $0 !== context.viewController && !context.for($0).view.isHidden }
                    .reversed()
                    .enumerated()
                    .forEach { (index, vc) in
                        let backView = context.for(vc).view
                        let currentTransition = context.removalTransitions[view]?[backView]?.0
                        if context.viewControllers.remaining.contains(vc) || !context.environment.overCurrentContext(context) {
                            context.removalTransitions[view, default: [:]][backView] = (
                                context.environment.moveToBackTransition(index + 1, context).reversed,
                                index + 1
                            )
                        }
                        context.removalTransitions[view]?[backView]?.0.beforeTransitionIfNeeded(view: backView, current: currentTransition)
                    }
            } else {
                context.removalTransitions[view]?.forEach {
                    if let backView = $0.key.value {
                        context.removalTransitions[view, default: [:]][backView] = (
                            context.environment.moveToBackTransition($0.value.1, context).constant(at: .removal(1)),
                            $0.value.1
                        )
                        context.removalTransitions[view]?[backView]?.0
                            .beforeTransitionIfNeeded(view: backView, current: $0.value.0)
                    }
                }
            }
            prepareBackground(context: context)
            prepare?(context)
            Self.animate(context: context, progress: context.direction.at(.start), animation: animation)
        } animation: { context in
            Self.animate(context: context, progress: context.direction.at(.end), animation: animation)
            if context.isTopController {
                context.updateStatusBar(style: context.viewController.preferredStatusBarStyle)
            }
        } completion: { context, completed in
            let finalContext = completed ? context : context.reversed
            let array = finalContext.viewControllers.toRemove
            if array.contains(finalContext.viewController) {
                let view = finalContext.view
                finalContext.insertionTransitions[view]?.setInitialState(view: view)
                finalContext.insertionTransitions[view] = nil
                finalContext.removalTransitions[view]?.forEach {
                    if let backView = $0.key.value {
                        $0.value.0.setInitialState(view: backView)
                    }
                }
                finalContext.removalTransitions[view] = nil
            }
            if finalContext.needHide {
                finalContext.container.isHidden = true
            }
            completeBackground(context: finalContext)
            completion?(context, completed)
        }
        .environment(\.contentTransition, { _ in transition })
        .environment(\.moveToBackTransition, { _, _ in moveToBackTransition })
        .environment(\.contentLayout, layout)
        .environment(\.overCurrentContext) { _ in overCurrentContext }
	}
}

public extension UIPresentation.Environment {
    
    var contentTransition: (UIPresentation.Context) -> UITransition<UIView> {
        get { self[\.contentTransition] ?? { _ in .identity } }
        set { self[\.contentTransition] = newValue }
    }
    
    var moveToBackTransition: (Int, UIPresentation.Context) -> UITransition<UIView> {
        get { self[\.moveToBackTransition] ?? { _, _ in .identity } }
        set { self[\.moveToBackTransition] = newValue }
    }
    
    var contentLayout: ContentLayout {
        get { self[\.contentLayout] ?? .fill }
        set { self[\.contentLayout] = newValue }
    }
    
    var overCurrentContext: (UIPresentation.Context) -> Bool {
        get { self[\.overCurrentContext] ?? { _ in false } }
        set { self[\.overCurrentContext] = newValue }
    }
}

extension UIPresentation.Context {
    
    var insertionTransitions: [Weak<UIView>: UITransition<UIView>] {
        get {
            cache[\.insertionTransitions] ?? [:]
        }
        nonmutating set {
            cache[\.insertionTransitions] = newValue
        }
    }
    
    var removalTransitions: [Weak<UIView>: [Weak<UIView>: (UITransition<UIView>, Int)]] {
        get {
            cache[\.removalTransitions] ?? [:]
        }
        nonmutating set {
            cache[\.removalTransitions] = newValue
        }
    }
}

private extension UIPresentation.Transition {
    
    static func animate(
        context: UIPresentation.Context,
        progress: Progress,
        animation: ((UIPresentation.Context, Progress) -> Void)?
    ) {
        let view = context.view
        context.insertionTransitions[view]?.update(progress: progress, view: view)
        context.removalTransitions[view]?.forEach {
            if let backView = $0.key.value {
                $0.value.0.update(progress: progress, view: backView)
            }
        }
        if let view = context.backgroundView {
            context.backgroundTransitions[view]?.update(progress: progress, view: view)
        }
        animation?(context, progress)
    }
    
    static func prepareBackground(
        context: UIPresentation.Context
    ) {
        let transition = context.environment.backgroundTransition.reversed
        guard !transition.isIdentity else { return }
        let backgroundView: UIView
        if let bgView = context.backgroundView {
            backgroundView = bgView
        } else {
            backgroundView = UIView()
            backgroundView.backgroundColor = .clear
            backgroundView.isUserInteractionEnabled = false
            context.backgroundView = backgroundView
            if context.environment.isOverlay {
                if let i = context.viewControllers.to.firstIndex(of: context.viewController), i > 0 {
                    let vc = context.viewControllers.to[i - 1]
                    context.for(vc).view.addSubview(backgroundView, layout: context.environment.backgroundLayout)
                }
            } else {
                context.container.insertSubview(backgroundView, at: 0, layout: context.environment.backgroundLayout)
            }
        }
        let current = context.backgroundTransitions[backgroundView]
        if context.needAnimate {
            context.backgroundTransitions[backgroundView] = transition
        } else {
            context.backgroundTransitions[backgroundView] = transition.constant(at: .insertion(1))
        }
        context.backgroundTransitions[backgroundView]?.beforeTransitionIfNeeded(view: backgroundView, current: current)
    }
    
    static func completeBackground(
        context: UIPresentation.Context
    ) {
        let array = context.viewControllers.toRemove
        
        if array.contains(context.viewController), let view = context.backgroundView {
            view.removeFromSuperview()
            context.backgroundTransitions[view] = nil
            context.backgroundView = nil
        }
    }
}
