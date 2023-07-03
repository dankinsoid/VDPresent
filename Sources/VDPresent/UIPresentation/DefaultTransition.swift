import UIKit
import VDTransition

public extension UIPresentation.Transition {

	static func `default`(
		prepare: ((UIPresentation.Context) -> Void)? = nil,
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
                prepare?(context)
                
                let needAnimate = context.isTopController && !context.viewControllers.isTopTheSame
                    || context.isChangingController && !needHide
                    
                let currentTransition = context.insertionTransitions[view]
                if needAnimate {
                    context.insertionTransitions[view] = context.environment.contentTransition.insertion
                } else if context.insertionTransitions[view] != nil {
                    context.insertionTransitions[view] = context.environment.contentTransition.constant(at: .insertion(1))
                }
                context.insertionTransitions[view]?.beforeTransitionIfNeeded(view: view, current: currentTransition)
                
                if context.isTopController, context.environment.applyTransitionOnBackControllers {
                    let array = context.environment.hideBackControllers
                        ? context.viewControllers.from
                        : context.viewControllers.remaining
                    array
                        .filter { $0 !== context.viewController && !context.view(for: $0).isHidden }
                        .forEach {
                            let backView = context.view(for: $0)
                            let currentTransition = context.removalTransitions[view]?[backView]
                            if context.viewControllers.remaining.contains($0) || context.environment.hideBackControllers {
                                context.removalTransitions[view, default: [:]][backView] = context.environment.contentTransition.removal.reversed
                            }
                            context.removalTransitions[view]?[backView]?.beforeTransitionIfNeeded(view: backView, current: currentTransition)
                        }
                } else {
                    context.removalTransitions[view]?.forEach {
                        if let backView = $0.key.value {
                            context.removalTransitions[view, default: [:]][backView] = context.environment.contentTransition.constant(at: .removal(1))
                            context.removalTransitions[view]?[backView]?.beforeTransitionIfNeeded(view: backView, current: $0.value)
                        }
                    }
                }
                
                if !context.environment.backgroundTransition.isIdentity {
                    let backgroundView: UIView
                    if let bgView = context.backgroundView {
                        backgroundView = bgView
                    } else {
                        backgroundView = UIView()
                        backgroundView.accessibilityIdentifier = backgroundViewID
                        backgroundView.backgroundColor = .clear
                        backgroundView.isUserInteractionEnabled = false
                        context.container.insertSubview(backgroundView, at: 0, layout: .fill)
                    }
                    let current = context.insertionTransitions[backgroundView]
                    if needAnimate {
                        context.insertionTransitions[backgroundView] = context.environment.backgroundTransition.reversed
                    } else {
                        context.insertionTransitions[backgroundView] = context.environment.backgroundTransition.constant(at: .insertion(0))
                    }
                    context.insertionTransitions[backgroundView]?.beforeTransitionIfNeeded(view: backgroundView, current: current)
                }
         
			case let .change(progress):
                context.currentViews.forEach { view in
                    context.insertionTransitions[view]?.update(progress: context.direction.at(progress), view: view)
                    context.removalTransitions[view]?.forEach {
                        if let backView = $0.key.value {
                            $0.value.update(progress: context.direction.at(progress), view: backView)
                        }
                    }
                }

			case let .end(completed):
                let array = completed
                    ? context.viewControllers.toRemove
                    : context.viewControllers.toInsert
                if array.contains(context.viewController) {
                    context.currentViews.forEach { view in
                        context.insertionTransitions[view]?.setInitialState(view: view)
                        context.insertionTransitions[view] = nil
                        context.removalTransitions[view]?.forEach {
                            if let backView = $0.key.value {
                                $0.value.setInitialState(view: backView)
                            }
                        }
                        context.removalTransitions[view] = nil
                    }
                }
                
                if context.needHide(completed ? .to : .from) {
                    context.container.isHidden = true
                }
                completion?(context, completed)
			}
		}
	}
}

public extension UIPresentation.Environment {
    
    var contentTransition: UITransition<UIView> {
        get { self[\.contentTransition] ?? .identity }
        set { self[\.contentTransition] = newValue }
    }
    var contentLayout: ContentLayout {
        get { self[\.contentLayout] ?? .fill }
        set { self[\.contentLayout] = newValue }
    }
    var backgroundTransition: UITransition<UIView> {
        get { self[\.backgroundTransition] ?? .identity }
        set { self[\.backgroundTransition] = newValue }
    }
    var applyTransitionOnBackControllers: Bool {
        get { self[\.applyTransitionOnBackControllers] ?? false }
        set { self[\.applyTransitionOnBackControllers] = newValue }
    }
    var hideBackControllers: Bool {
        get { self[\.hideBackControllers] ?? false }
        set { self[\.hideBackControllers] = newValue }
    }
}

private let backgroundViewID = "BackgroundView"

extension UIPresentation.Context {
    
    var insertionTransitions: [Weak<UIView>: UITransition<UIView>] {
        get {
            cache[\.insertionTransitions] ?? [:]
        }
        nonmutating set {
            cache[\.insertionTransitions] = newValue
        }
    }
    
    var removalTransitions: [Weak<UIView>: [Weak<UIView>: UITransition<UIView>]] {
        get {
            cache[\.removalTransitions] ?? [:]
        }
        nonmutating set {
            cache[\.removalTransitions] = newValue
        }
    }
    
    var currentViews: [UIView] {
        [view, backgroundView].compactMap { $0 }
    }
    
    var backgroundView: UIView? {
        container.subviews
            .first(where: { $0.accessibilityIdentifier == backgroundViewID })
    }
    
    var isChangingController: Bool {
        !viewControllers.to.contains(viewController) || !viewControllers.from.contains(viewController)
    }
    
    var isRemainingController: Bool {
        !isChangingController
    }
    
    var isTopController: Bool {
        viewControllers.top.contains(viewController)
    }
    
    var isSecondController: Bool {
        viewControllers.second.contains(viewController)
    }
    
    func needHide(_ key: UITransitionContextViewControllerKey) -> Bool {
        let all = viewControllers[key]
        if let i = all.lastIndex(where: { environment(for: $0).hideBackControllers }),
           let j = all.firstIndex(of: viewController) {
            return i > j
        } else {
            return false
        }
    }
}

extension UIPresentation.Context.Controllers {
    
    var changing: [UIViewController] {
		direction == .insertion ? toInsert : toRemove
	}

	var remaining: [UIViewController] {
		to.filter(from.contains)
	}
    
    var top: [UIViewController] {
        direction == .insertion
            ? Array(to.suffix(1))
            : Array(from.suffix(1))
    }
    
    var second: [UIViewController] {
        direction == .insertion
            ? Array(from.suffix(1))
            : Array(to.suffix(1))
    }
}

extension Dictionary {
    
    subscript<T: AnyObject>(_ key: T?) -> Value? where Key == Weak<T> {
        get { self[Weak(key)] }
        set { self[Weak(key)] = newValue }
    }
    
    subscript<T: AnyObject>(_ key: T?, default value: Value) -> Value where Key == Weak<T> {
        get { self[Weak(key), default: value] }
        set { self[Weak(key)] = newValue }
    }
}
