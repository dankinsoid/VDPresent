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
                for viewController in context.viewControllersToInsert {
                    context.container(for: viewController)
                        .addSubview(
                            context.view(for: viewController),
                            layout: context.environment.contentLayout
                        )
                }
                context.allViewControllers.forEach {
                    context.container(for: $0).isHidden = false
                }
                
                prepare?(context)
                let changing = context.environment.animateBackControllersReorder
                    ? context.changingControllers
                    : context.topViewController
                
                changing.forEach {
                    let view = context.view(for: $0)
                    let currentTransition = context.transitions[view]
                    if context.toViewControllers.contains($0) {
                        context.transitions[view] = context.environment.contentTransition
                    } else {
                        context.transitions[view] = context.environment.contentTransition.inverted
                    }
                    context.transitions[view]?.beforeTransitionIfNeeded(view: view, current: currentTransition)
                    
                    if !context.environment.backgroundTransition.isIdentity {
                        let id = "BackgroundView"
                        if let backgroundView = context.container(for: $0).subviews
                            .first(where: { $0.accessibilityIdentifier == id }) {
                            let current = context.transitions[backgroundView]
                            context.transitions[backgroundView] = context.environment.backgroundTransition.reversed
                            context.transitions[backgroundView]?.beforeTransitionIfNeeded(view: backgroundView, current: current)
                        } else {
                            let backgroundView = UIView()
                            backgroundView.accessibilityIdentifier = id
                            backgroundView.backgroundColor = .clear
                            backgroundView.isUserInteractionEnabled = false
                            context.container(for: $0).insertSubview(backgroundView, at: 0, layout: .fill)
                            context.transitions[backgroundView] = context.environment.backgroundTransition.reversed
                            context.transitions[backgroundView]?.beforeTransition(view: backgroundView)
                        }
                    }
                }
                
                if context.environment.applyTransitionOnBackControllers {
                    let controllers = context.environment.animateBackControllersReorder
                        ? context.remainingControllers
                        : context.secondViewController
                    controllers.forEach {
                        let view = context.view(for: $0)
                        let current = context.transitions[view]
                        context.transitions[view] = context.direction == .insertion
                            ? context.environment.contentTransition.inverted.reversed
                            : context.environment.contentTransition.reversed
                        context.transitions[view]?.beforeTransitionIfNeeded(view: view, current: current)
                    }
                }

			case let .change(direction, progress):
                var controllers = context.environment.animateBackControllersReorder
                    ? context.changingControllers
                    : context.topViewController
                if context.environment.applyTransitionOnBackControllers {
                    controllers += context.environment.animateBackControllersReorder
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
                if context.environment.hideBackControllers {
                    let array = completed
                        ? context.toViewControllers
                        : context.fromViewControllers
                    if !array.isEmpty {
                        array.dropLast().forEach {
                            context.container(for: $0).isHidden = true
                            let view = context.view(for: $0)
                            context.transitions[view]?.setInitialState(view: view)
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
    var animateBackControllersReorder: Bool {
        get { self[\.animateBackControllersReorder] ?? true }
        set { self[\.animateBackControllersReorder] = newValue }
    }
    var hideBackControllers: Bool {
        get { self[\.hideBackControllers] ?? false }
        set { self[\.hideBackControllers] = newValue }
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
