import UIKit
import VDTransition

public extension UIPresentation.Transition {

	init(
		content: UITransition<UIView>,
		background: UITransition<UIView>,
		applyTransitionOnBothControllers: Bool = false,
		prepare: ((UIPresentation.Context) -> Void)? = nil,
		completion: ((UIPresentation.Context, Bool) -> Void)? = nil
	) {
        self.init { context, state in
			switch state {
			case .begin:
                prepare?(context)
                context.changingControllers.forEach {
                    let view = context.view(for: $0)
                    context.transitions[view]?.setInitialState(view: view)
                    context.transitions[view] = content
                    
                    if !background.isIdentity {
                        let id = "BackgroundView"
                        if let backgroundView = context.container(for: $0).subviews
                            .first(where: { $0.accessibilityIdentifier == id }) {
                            context.transitions[backgroundView]?.setInitialState(view: backgroundView)
                            context.transitions[backgroundView] = background.reversed
                        } else {
                            let backgroundView = UIView()
                            backgroundView.accessibilityIdentifier = id
                            backgroundView.backgroundColor = .clear
                            backgroundView.isUserInteractionEnabled = false
                            context.container(for: $0).insertSubview(backgroundView, at: 0, alignment: .edges())
                            context.transitions[backgroundView] = background.reversed
                        }
                    }
                }
                
                if applyTransitionOnBothControllers {
                    context.backControllers.forEach {
                        let view = context.view(for: $0)
                        context.transitions[view]?.setInitialState(view: view)
                        context.transitions[view] = content.inverted
                    }
                }
        
                context.transitions.forEach {
                    if let view = $0.key {
                        context.transitions[view]?.beforeTransition(view: view)
                    }
                }

			case let .change(progress):
                let changingViews = context.changingControllers.map(context.container)
                context.transitions.forEach { view, _ in
                    if let view, changingViews.contains(where: view.isDescendant) {
                        context.transitions[view]?.update(progress: progress, view: view)
                    }
                }

			case let .end(completed, animation):
                let viewsToRemove = context.viewControllersToRemove.map(context.container)
                let block: () -> Void = {
                    context.transitions.forEach { view, _ in
                        if let view, viewsToRemove.contains(where: view.isDescendant) {
                            context.transitions[view]?.setInitialState(view: view)
                            context.transitions[view] = nil
                        }
                    }
                }
                if let animation {
                    UIView.animate(with: animation) {
                        block()
                    } completion: { _ in
                        completion?(context, completed)
                    }
                } else {
                    block()
                    completion?(context, completed)
                }
			}
		}
	}
}

extension UIPresentation.Context {

	var transitions: [UIView?: UITransition<UIView>] {
		get {
			cache[\.transitions] ?? [:]
		}
		nonmutating set {
			cache[\.transitions] = newValue
		}
	}

	var changingControllers: [UIViewController] {
		direction == .insertion ? viewControllersToInsert : viewControllersToRemove
	}

	var backControllers: [UIViewController] {
		(direction == .insertion ? viewControllersToRemove : viewControllersToInsert) + remainingControllers
	}

	var remainingControllers: [UIViewController] {
		toViewControllers.filter(fromViewControllers.contains)
	}
}
