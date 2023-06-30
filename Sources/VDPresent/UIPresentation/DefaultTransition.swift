import UIKit
import VDTransition

public extension UIPresentation.Transition {

	init(
		content: UITransition<UIView>,
        layout: ContentLayout,
		background: UITransition<UIView>,
		applyTransitionOnBackControllers: Bool,
        animateBackControllersReorder: Bool,
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
                let changing = animateBackControllersReorder
                    ? context.changingControllers
                    : context.topViewController
                
                changing.forEach {
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
                
                if applyTransitionOnBackControllers {
                    let controllers = animateBackControllersReorder
                        ? context.remainingControllers
                        : context.secondViewController
                    controllers.forEach {
                        let view = context.view(for: $0)
                        let current = context.transitions[view]
                        context.transitions[view] = context.direction == .insertion
                            ? content.inverted.reversed
                            : content.reversed
                        context.transitions[view]?.beforeTransitionIfNeeded(view: view, current: current)
                    }
                }

			case let .change(direction, progress):
                var controllers = animateBackControllersReorder
                    ? context.changingControllers
                    : context.topViewController
                if applyTransitionOnBackControllers {
                    controllers += animateBackControllersReorder
                        ? context.remainingControllers
                        : context.secondViewController
                }
                let views = Set(controllers.map { context.container(for: $0) as UIView })
                context.transitions.forEach { key, _ in
                    if let view = key.value, views.contains(where: view.isDescendant) {
                        context.transitions[view]?.update(progress: direction.at(progress), view: view)
                    }
                }

			case let .end(completed):
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
    
    var allViewControllers: [UIViewController] {
        changingControllers + remainingControllers
    }
    
    var topViewController: [UIViewController] {
        direction == .insertion
            ? Array(toViewControllers.suffix(1))
            : Array(fromViewControllers.suffix(1))
    }
    
    var secondViewController: [UIViewController] {
        direction == .insertion
            ? Array(fromViewControllers.suffix(1))
            : Array(toViewControllers.suffix(1))
    }
}

extension Dictionary {
    
    subscript<T: AnyObject>(_ key: T?) -> Value? where Key == Weak<T> {
        get { self[Weak(key)] }
        set { self[Weak(key)] = newValue }
    }
}
