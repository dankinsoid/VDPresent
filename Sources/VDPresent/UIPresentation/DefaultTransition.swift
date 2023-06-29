import UIKit
import VDTransition

public extension UIPresentation.Transition {

	init(
		content: UITransition<UIView>,
        layout: ContentLayout,
		background: UITransition<UIView>,
		applyTransitionOnBothControllers: Bool = false,
		prepare: ((UIPresentation.Context) -> Void)? = nil,
		completion: ((UIPresentation.Context, Bool) -> Void)? = nil
	) {
        self.init { context, state in
			switch state {
			case .begin:
                for viewController in context.viewControllersToInsert {
                    context.container(for: viewController)
                        .addSubview(
                            context.view(for: viewController),
                            layout: layout
                        )
                }
                
                prepare?(context)
                context.changingControllers.forEach {
                    let view = context.view(for: $0)
                    let currentTransition = context.transitions[view]
                    if context.toViewControllers.contains($0) {
                        context.transitions[view] = content
                    } else {
                        context.transitions[view] = content.inverted
                    }
                    context.transitions[view]?.beforeTransitionIfNeeded(view: view, current: currentTransition)
                    
                    if !background.isIdentity {
                        let id = "BackgroundView"
                        if let backgroundView = context.container(for: $0).subviews
                            .first(where: { $0.accessibilityIdentifier == id }) {
                            let current = context.transitions[backgroundView]
                            context.transitions[backgroundView] = background.reversed
                            context.transitions[backgroundView]?.beforeTransitionIfNeeded(view: backgroundView, current: current)
                        } else {
                            let backgroundView = UIView()
                            backgroundView.accessibilityIdentifier = id
                            backgroundView.backgroundColor = .clear
                            backgroundView.isUserInteractionEnabled = false
                            context.container(for: $0).insertSubview(backgroundView, at: 0, layout: .fill)
                            context.transitions[backgroundView] = background.reversed
                            context.transitions[backgroundView]?.beforeTransitionIfNeeded(view: backgroundView)
                        }
                    }
                }
                
//                if applyTransitionOnBothControllers {
//                    context.backControllers.forEach {
//                        let view = context.view(for: $0)
//                        context.transitions[view] = content.inverted
//                    }
//                }

			case let .change(progress):
                let changingViews = context.changingControllers.map(context.container)
                context.transitions.forEach { key, _ in
                    if let view = key.value, changingViews.contains(where: view.isDescendant) {
                        context.transitions[view]?.update(progress: progress, view: view)
                    }
                }

			case let .end(completed, _):
                let array = completed
                    ? context.viewControllersToRemove.map(context.container)
                    : context.viewControllersToInsert.map(context.container)
                context.transitions.forEach { key, _ in
                    if let view = key.value, array.contains(where: view.isDescendant) {
                        context.transitions[view]?.setInitialState(view: view)
                        context.transitions[view] = nil
                    }
                }
                completion?(context, completed)
			}
		}
	}
}

extension UIPresentation.Context {

	var transitions: [Weak<UIView>: UITransition<UIView>] {
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

extension Dictionary {
    
    subscript<T: AnyObject>(_ key: T?) -> Value? where Key == Weak<T> {
        get { self[Weak(key)] }
        set { self[Weak(key)] = newValue }
    }
}
