import UIKit
import VDTransition

public extension UIPresentation.Transition {

	static func `default`(
        transition: UIViewTransition = .identity,
        layout: ContentLayout = .fill,
        applyTransitionOnBackControllers: Bool = false,
        contextTransparencyDeep: Int? = nil,
		prepare: ((UIPresentation.Context) -> Void)? = nil,
        animation: ((UIPresentation.Context, Progress.Edge) -> Void)? = nil,
		completion: ((UIPresentation.Context, Bool) -> Void)? = nil
	) -> UIPresentation.Transition {
        UIPresentation.Transition { context, state in
			switch state {
			case .begin:
                let view = context.view
                if !context.viewControllers.from.contains(context.viewController) {
                    context.container
                        .addSubview(
                            view,
                            layout: context.environment.contentLayout
                        )
                }
                let needHide = context.needHide(.to)
                if context.container.isHidden, !needHide {
                    context.container.isHidden = false
                }
                
                let needAnimate = context.needAnimate
                    
                let currentTransition = context.insertionTransitions[view]
                if needAnimate {
                    context.insertionTransitions[view] = context.environment.contentTransition(0, context).insertion
                } else if context.insertionTransitions[view] != nil {
                    context.insertionTransitions[view] = context.environment.contentTransition(0, context).constant(at: .insertion(1))
                }
                context.insertionTransitions[view]?.beforeTransitionIfNeeded(view: view, current: currentTransition)
                
                if context.isTopController, context.environment.applyTransitionOnBackControllers {
                    let array = context.environment.overCurrentContext
                        ? context.viewControllers.from
                        : context.viewControllers.remaining
                    array
                        .filter { $0 !== context.viewController && !context.view(for: $0).isHidden }
                        .suffix((context.environment.contextTransparencyDeep ?? 0) + 1)
                        .reversed()
                        .enumerated()
                        .forEach { (index, vc) in
                            let backView = context.view(for: vc)
                            let currentTransition = context.removalTransitions[view]?[backView]?.0
                            if context.viewControllers.remaining.contains(vc) || !context.environment.overCurrentContext {
                                context.removalTransitions[view, default: [:]][backView] = (
                                    context.environment.contentTransition(index + 1, context).removal.reversed,
                                    index + 1
                                )
                            }
                            context.removalTransitions[view]?[backView]?.0.beforeTransitionIfNeeded(view: backView, current: currentTransition)
                        }
                } else {
                    context.removalTransitions[view]?.forEach {
                        if let backView = $0.key.value {
                            context.removalTransitions[view, default: [:]][backView] = (
                                context.environment.contentTransition($0.value.1, context).constant(at: .removal(1)),
                                $0.value.1
                            )
                            context.removalTransitions[view]?[backView]?.0
                                .beforeTransitionIfNeeded(view: backView, current: $0.value.0)
                        }
                    }
                }
                prepare?(context)
         
			case let .change(progress):
                let view = context.view
                context.insertionTransitions[view]?.update(progress: context.direction.at(progress), view: view)
                context.removalTransitions[view]?.forEach {
                    if let backView = $0.key.value {
                        $0.value.0.update(progress: context.direction.at(progress), view: backView)
                    }
                }
                animation?(context, progress)

			case let .end(completed):
                let array = completed
                    ? context.viewControllers.toRemove
                    : context.viewControllers.toInsert
                if array.contains(context.viewController) {
                    let view = context.view
                    context.insertionTransitions[view]?.setInitialState(view: view)
                    context.insertionTransitions[view] = nil
                    context.removalTransitions[view] = nil
                }
                
                if context.needHide(completed ? .to : .from) {
                    context.container.isHidden = true
                }
                completion?(context, completed)
			}
		}
        .environment(\.contentTransition, { _, _ in transition })
        .environment(\.contentLayout, layout)
        .environment(\.applyTransitionOnBackControllers, applyTransitionOnBackControllers)
        .environment(\.contextTransparencyDeep, contextTransparencyDeep)
	}
}

public extension UIPresentation.Environment {
    
    var contentTransition: (Int, UIPresentation.Context) -> UITransition<UIView> {
        get { self[\.contentTransition] ?? { _, _ in .identity } }
        set { self[\.contentTransition] = newValue }
    }
    
    var contentLayout: ContentLayout {
        get { self[\.contentLayout] ?? .fill }
        set { self[\.contentLayout] = newValue }
    }
    
    var applyTransitionOnBackControllers: Bool {
        get { self[\.applyTransitionOnBackControllers] ?? false }
        set { self[\.applyTransitionOnBackControllers] = newValue }
    }
    
    var contextTransparencyDeep: Int? {
        get { self[\.contextTransparencyDeep] ?? nil }
        set { self[\.contextTransparencyDeep] = newValue }
    }
    
    var overCurrentContext: Bool {
        get { contextTransparencyDeep ?? 1 > 0 }
        set { contextTransparencyDeep = newValue ? nil : 0 }
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
