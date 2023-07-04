import UIKit
import VDTransition

public extension UIPresentation.Transition {
    
    func withBackground(
        _ color: UIColor,
        layout: ContentLayout = .fill
    ) -> UIPresentation.Transition {
        withBackground(
            color == .clear
                ? .identity
                : .backgroundColor(color, default: color.withAlphaComponent(0)),
            layout: layout
        )
    }
    
    func withBackground(
        _ transition: UIViewTransition,
        layout: ContentLayout = .fill
    ) -> UIPresentation.Transition {
        with { context, state in
            switch state {
            case .begin:
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
                            context.container(for: vc).addSubview(backgroundView, layout: .match(context.view(for: vc)))
                        }
                    } else {
                        context.container.insertSubview(backgroundView, at: 0, layout: context.environment.backgroundLayout)
                    }
                }
                let current = context.backgroundTransitions[backgroundView]
                if context.needAnimate {
                    context.backgroundTransitions[backgroundView] = transition
                } else if context.needHide(.to) {
                    context.backgroundTransitions[backgroundView] = transition.reversed.insertion
                } else if context.needHide(.from) {
                    context.backgroundTransitions[backgroundView] = transition.reversed.removal
                } else {
                    context.backgroundTransitions[backgroundView] = transition.constant(at: .insertion(1))
                }
                context.backgroundTransitions[backgroundView]?.beforeTransitionIfNeeded(view: backgroundView, current: current)
                
            case let .change(edge):
                if let view = context.backgroundView {
                    context.backgroundTransitions[view]?.update(progress: context.direction.at(edge), view: view)
                }
                
            case let .end(completed):
                let array = completed
                    ? context.viewControllers.toRemove
                    : context.viewControllers.toInsert
                
                if array.contains(context.viewController), let view = context.backgroundView {
                    if let container = view.superview as? UIStackControllerContainer {
                        container.remove(subview: view)
                    } else {
                        view.removeFromSuperview()
                    }
                    context.backgroundTransitions[view] = nil
                    context.backgroundView = nil
                }
            }
        }
        .environment(\.backgroundTransition, transition)
        .environment(\.backgroundLayout, layout)
        .environment(\.isOverlay, false)
    }
    
    func withOverlay(
        _ color: UIColor
    ) -> UIPresentation.Transition {
        withBackground(color).environment(\.isOverlay, true)
    }
    
    func withOverlay(
        _ transition: UIViewTransition
    ) -> UIPresentation.Transition {
        withBackground(transition).environment(\.isOverlay, true)
    }
}

public extension UIPresentation.Environment {
    
    var backgroundLayout: ContentLayout {
        get { self[\.backgroundLayout] ?? .fill }
        set { self[\.backgroundLayout] = newValue }
    }
    
    var backgroundTransition: UITransition<UIView> {
        get { self[\.backgroundTransition] ?? .identity }
        set { self[\.backgroundTransition] = newValue }
    }
}

extension UIPresentation.Environment {
    
    var isOverlay: Bool {
        get { self[\.isOverlay] ?? false }
        set { self[\.isOverlay] = newValue }
    }
}

extension UIPresentation.Context {
    
    var backgroundTransitions: [Weak<UIView>: UITransition<UIView>] {
        get {
            cache[\.backgroundTransitions] ?? [:]
        }
        nonmutating set {
            cache[\.backgroundTransitions] = newValue
        }
    }
    
    var backgroundView: UIView? {
        get { backgroundViews[view]?.value }
        nonmutating set {
            if let newValue {
                backgroundViews[view] = Weak(newValue)
            } else {
                backgroundViews[view] = nil
            }
        }
    }
}

private extension UIPresentation.Context {
    
    var backgroundViews: [Weak<UIView>: Weak<UIView>] {
        get { cache[\.backgroundViews] ?? [:] }
        nonmutating set { cache[\.backgroundViews] = newValue }
    }
}
