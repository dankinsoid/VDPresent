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
                : .backgroundColor(color, default: color.withAlphaComponent(0))
        )
    }
    
    func withBackground(
        _ transition: UIViewTransition,
        layout: ContentLayout = .fill
    ) -> UIPresentation.Transition {
        with { context, state in
            switch state {
            case .begin:
                let transition = context.environment.backgroundTransition
                guard !transition.isIdentity else { return }
                let backgroundView: UIView
                if let bgView = context.backgroundView {
                    backgroundView = bgView
                } else {
                    backgroundView = UIView()
                    backgroundView.accessibilityIdentifier = backgroundViewID
                    backgroundView.backgroundColor = .clear
                    backgroundView.isUserInteractionEnabled = false
                    context.container.insertSubview(backgroundView, at: 0, layout: context.environment.backgroundLayout)
                }
                let current = context.backgroundTransitions[backgroundView]
                if context.needAnimate {
                    context.backgroundTransitions[backgroundView] = transition.reversed
                } else {
                    context.backgroundTransitions[backgroundView] = transition.constant(at: .insertion(0))
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
                    view.removeFromSuperview()
                    context.backgroundTransitions[view] = nil
                }
            }
        }
        .environment(\.backgroundTransition, transition)
        .environment(\.backgroundLayout, layout)
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
        container.subviews
            .first(where: { $0.accessibilityIdentifier == backgroundViewID })
    }
}

private let backgroundViewID = "BackgroundView"
