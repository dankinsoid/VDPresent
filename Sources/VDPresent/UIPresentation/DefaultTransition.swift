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
                context.container.isHidden = false
                
                prepare?(context)
                
                let currentTransition = context.transitions[view]
                if context.isTopController {
                    context.transitions[view] = context.environment.contentTransition.insertion
                } else if context.isSecondController, context.environment.applyTransitionOnBackControllers, context.isRemainingController || context.environment.hideBackControllers {
                    context.transitions[view] = context.environment.contentTransition.removal
                } else if !context.environment.hideBackControllers, context.isChangingController {
                    context.transitions[view] = context.environment.contentTransition.insertion
                } else {
                    context.transitions[view]?.setInitialState(view: view)
                    context.transitions[view] = nil
                }
                context.transitions[view]?.beforeTransitionIfNeeded(view: view, current: currentTransition)
                
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
                    let current = context.transitions[backgroundView]
                    if context.isTopController || context.isChangingController && !context.environment.hideBackControllers {
                        context.transitions[backgroundView] = context.environment.backgroundTransition.reversed
                    } else {
                        context.transitions[backgroundView] = context.environment.backgroundTransition.constant(at: .insertion(0))
                    }
                    context.transitions[backgroundView]?.beforeTransitionIfNeeded(view: backgroundView, current: current)
                }
         
			case let .change(progress):
                context.currentViews.forEach { view in
                    context.transitions[view]?.update(progress: context.direction.at(progress), view: view)
                }

			case let .end(completed):
                let array = completed
                    ? context.viewControllers.toRemove
                    : context.viewControllers.toInsert
                if array.contains(context.viewController) {
                    context.currentViews.forEach { view in
                        context.transitions[view]?.setInitialState(view: view)
                        context.transitions[view] = nil
                    }
                }
                if context.environment.hideBackControllers {
                    let array = completed
                        ? context.viewControllers.to
                        : context.viewControllers.from
                    if !array.isEmpty, array.dropLast().contains(context.viewController) {
                        context.container.isHidden = true
                        context.currentViews.forEach { view in
                            context.transitions[view]?.setInitialState(view: view)
                            context.transitions[view] = nil
                        }
                    }
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
    
    var transitions: [Weak<UIView>: UITransition<UIView>] {
        get {
            cache[\.transitions] ?? [:]
        }
        nonmutating set {
            cache[\.transitions] = newValue
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
}
