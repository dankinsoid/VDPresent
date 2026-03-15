import UIKit
import VDTransition

public extension UIPresentation.Transition {
	
	/// Base transition that orchestrates the full presentation lifecycle: insertion animation,
	/// move-to-back animation for views below, background view, status bar, and cleanup.
	///
	/// All visual behaviour is configured via environment keys — call `.environment(...)` on the
	/// result to set `contentTransition`, `moveToBackTransition`, `contentLayout`, etc.
	///
	/// Three lifecycle phases, executed in order:
	/// - **prepare** — layout, initial states, `additionalPrepare`, progress set to `.start`
	/// - **animation** — progress driven to `.end`, status bar updated
	/// - **completion** — state reset/cleanup, container visibility, `completion` callback
	///
	/// - Parameters:
	///   - additionalPrepare: Called at the end of the prepare phase. Use to set up any state
	///     that cannot be expressed via environment keys.
	///   - additionalAnimation: Called on every progress update inside the animation block.
	///     Runs in the same `UIView.animate` batch as the built-in transitions.
	///   - completion: Called after the transition finishes. `completed` is `false` when the
	///     transition was cancelled (e.g. interactive gesture reversed).
	static func base(
		additionalPrepare: ((UIPresentation.Context) -> Void)? = nil,
		additionalAnimation: ((UIPresentation.Context, Progress) -> Void)? = nil,
		completion: ((UIPresentation.Context, Bool) -> Void)? = nil
	) -> UIPresentation.Transition {
		UIPresentation.Transition(
			prepare: { context in
				if context.isTopController || !context.needHide {
					context.container.isHidden = false
				}
				prepareInsertionTransition(context: context)
				if context.isTopController {
					// This VC is becoming top — animate visible views beneath it moving to back.
					prepareBackViewTransitions(context: context)
				} else {
					// This VC is not top — freeze existing back-view transitions at their final
					// state so they don't re-animate during nested layout passes.
					freezeBackViewTransitions(context: context)
				}
				prepareBackground(context: context)
				additionalPrepare?(context)
				Self.animate(context: context, progress: context.direction.at(.start), animation: additionalAnimation)
			},
			animation: { context in
				Self.animate(context: context, progress: context.direction.at(.end), animation: additionalAnimation)
				if context.isTopController {
					context.updateStatusBar(style: context.viewController.preferredStatusBarStyle)
				}
			},
			completion: { context, completed in
				let finalContext = completed ? context : context.reversed
				cleanupTransitions(context: finalContext)
				if finalContext.needHide {
					finalContext.container.isHidden = true
				}
				completeBackground(context: finalContext)
				completion?(context, completed)
			}
		)
	}
}

public extension UIPresentation.Environment {

    /// Animation applied to the incoming view. Default: `.identity` (no animation).
    var contentTransition: (UIPresentation.Context) -> UITransition<UIView> {
        get { self[\.contentTransition] ?? { _ in .identity } }
        set { self[\.contentTransition] = newValue }
    }

    /// Animation applied to views moving to the back when a new VC becomes top.
    /// `Int` is the depth index (1 = immediate predecessor, 2 = one below, …). Default: `.identity`.
    var moveToBackTransition: (Int, UIPresentation.Context) -> UITransition<UIView> {
        get { self[\.moveToBackTransition] ?? { _, _ in .identity } }
        set { self[\.moveToBackTransition] = newValue }
    }

    /// Layout constraints applied to the presented view's container. Default: `.fill`.
    var contentLayout: ContentLayout {
        get { self[\.contentLayout] ?? .fill }
        set { self[\.contentLayout] = newValue }
    }

    /// Whether this presentation renders over the current context (like a sheet) rather than
    /// replacing it. Affects how the view hierarchy is structured. Default: `false`.
    var overCurrentContext: (UIPresentation.Context) -> Bool {
        get { self[\.overCurrentContext] ?? { _ in false } }
        set { self[\.overCurrentContext] = newValue }
    }
}

extension UIPresentation.Context {
	
	/// Per-context cache of insertion transitions, keyed by the presented view.
	/// Populated in prepare, consumed in animate, cleared in cleanup.
	var insertionTransitions: [Weak<UIView>: UITransition<UIView>] {
		get { cache[\.insertionTransitions] ?? [:] }
		nonmutating set { cache[\.insertionTransitions] = newValue }
	}
	
	/// Per-context cache of move-to-back transitions for views beneath the presented VC.
	/// Outer key: presented view. Inner key: back view. Value: (transition, depth index).
	var removalTransitions: [Weak<UIView>: [Weak<UIView>: (UITransition<UIView>, Int)]] {
		get { cache[\.removalTransitions] ?? [:] }
		nonmutating set { cache[\.removalTransitions] = newValue }
	}
}

private extension UIPresentation.Transition {

    /// Configures the animation for the view being inserted.
    /// If animation is not needed (non-animated context), snaps to the fully inserted state
    /// so the view doesn't appear mid-transition when the stack is rebuilt without animation.
    static func prepareInsertionTransition(context: UIPresentation.Context) {
        let view = context.view
        let currentTransition = context.insertionTransitions[view]
        if context.needAnimate {
            context.insertionTransitions[view] = context.environment.contentTransition(context)
        } else if context.insertionTransitions[view] != nil {
            context.insertionTransitions[view] = context.environment.contentTransition(context).constant(at: .insertion(1))
        }
        context.insertionTransitions[view]?.beforeTransitionIfNeeded(view: view, current: currentTransition)
    }

    /// Configures move-to-back animations for all visible views beneath this VC.
    /// Only called when this VC is the new top — it is responsible for pushing others behind it.
    /// Views are enumerated in reverse so depth index 1 is the immediate predecessor.
    static func prepareBackViewTransitions(context: UIPresentation.Context) {
        let view = context.view
        let from = context.viewControllers.from.map(viewId).joined(separator: ",")
        let to   = context.viewControllers.to.map(viewId).joined(separator: ",")
        print("🔵 prepareBack  vc=\(viewId(context.viewController))  dir=\(context.direction)  [\(from)]→[\(to)]")
        context.viewControllers.from
            .filter { $0 !== context.viewController && !context.for($0).view.isHidden }
            .reversed()
            .enumerated()
            .forEach { (index, vc) in
                let backView = context.for(vc).view
                let before = fmt(backView)
                let currentTransition = context.removalTransitions[view]?[backView]?.0
                context.removalTransitions[view, default: [:]][backView] = (
                    context.environment.moveToBackTransition(index + 1, context).reversed,
                    index + 1
                )
                context.removalTransitions[view]?[backView]?.0
                    .beforeTransitionIfNeeded(view: backView, current: currentTransition)
                print("   back[\(index+1)] \(viewId(vc))  \(before) → \(fmt(backView))")
            }
    }

    /// Freezes existing back-view transitions at their final (fully-removed) state.
    /// Called when this VC is not the top controller — back views are already positioned
    /// and must not re-animate if a nested VC triggers another layout pass.
    static func freezeBackViewTransitions(context: UIPresentation.Context) {
        let view = context.view
        guard !(context.removalTransitions[view]?.isEmpty ?? true) else { return }
        print("🟡 freeze  vc=\(viewId(context.viewController))")
        context.removalTransitions[view]?.forEach {
            if let backView = $0.key.value {
                let before = fmt(backView)
                context.removalTransitions[view, default: [:]][backView] = (
                    context.environment.moveToBackTransition($0.value.1, context).constant(at: .removal(1)),
                    $0.value.1
                )
                context.removalTransitions[view]?[backView]?.0
                    .beforeTransitionIfNeeded(view: backView, current: $0.value.0)
                print("   \(viewName(backView))  \(before) → \(fmt(backView))")
            }
        }
    }

    /// Resets insertion and removal transitions to their initial state and clears them from the cache.
    /// Only runs when this VC is being removed from the stack — leaves state clean for potential re-presentation.
    static func cleanupTransitions(context: UIPresentation.Context) {
        guard context.viewControllers.toRemove.contains(context.viewController) else { return }
        let view = context.view
        print("🔴 cleanup  vc=\(viewId(context.viewController))")
        context.insertionTransitions[view]?.setInitialState(view: view)
        context.insertionTransitions[view] = nil
        context.removalTransitions[view]?.forEach {
            if let backView = $0.key.value {
                let before = fmt(backView)
                $0.value.0.setInitialState(view: backView)
                print("   setInitialState \(viewName(backView))  \(before) → \(fmt(backView))")
            }
        }
        context.removalTransitions[view] = nil
    }

    /// Drives all active transitions (insertion, removal, background) to `progress`,
    /// then calls `animation` so callers can apply additional effects in the same pass.
    static func animate(
        context: UIPresentation.Context,
        progress: Progress,
        animation: ((UIPresentation.Context, Progress) -> Void)?
    ) {
        let view = context.view
			let before = fmt(view)
        context.insertionTransitions[view]?.update(progress: progress, view: view)
				print("⚡ animate  vc=\(viewId(context.viewController)), \(before) → \(fmt(view))  @\(progress)")
        context.removalTransitions[view]?.forEach {
            if let backView = $0.key.value {
							let before = fmt(backView)
                $0.value.0.update(progress: progress, view: backView)
                // Only log at start/end to avoid flooding during interactive gestures
                if progress.value == 0 || progress.value == 1 {
                    print("⚡ animate  vc=\(viewId(context.viewController)) : \(viewName(backView)), \(before) → \(fmt(backView))  @\(progress)")
                }
            }
        }
        if let view = context.backgroundView {
            context.backgroundTransitions[view]?.update(progress: progress, view: view)
        }
        animation?(context, progress)
    }

    // MARK: - Debug helpers

    private static func viewId(_ vc: UIViewController) -> String {
        vc.view.accessibilityIdentifier ?? String(describing: type(of: vc))
    }

    private static func viewName(_ view: UIView) -> String {
        (view as? UIStackViewWrapper)?.wrapped.accessibilityIdentifier
            ?? view.accessibilityIdentifier
            ?? String(describing: type(of: view))
    }

    /// Short readable representation of a view's current transform offset.
    private static func fmt(_ view: UIView) -> String {
        let tx = view.affineTransform.tx
        let ty = view.affineTransform.ty
        if tx == 0 && ty == 0 { return "center" }
        if ty == 0 { return "tx=\(Int(tx))" }
        if tx == 0 { return "ty=\(Int(ty))" }
        return "tx=\(Int(tx)) ty=\(Int(ty))"
    }

    /// Creates or reuses the background/overlay view and registers its transition.
    /// No-ops when `backgroundTransition` is `.identity` — no view is created in that case.
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
    
    /// Removes the background view from the hierarchy and clears its cached transition
    /// when this VC is being dismissed. Safe to call when no background view exists.
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
