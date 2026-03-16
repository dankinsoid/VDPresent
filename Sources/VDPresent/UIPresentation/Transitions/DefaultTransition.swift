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
	/// - **prepare** — layout, initial states for changing controllers, snap to `.start`
	/// - **animation** — reset all views to identity, then apply own + back-view effects to `.end`
	/// - **completion** — state reset/cleanup, container visibility, `completion` callback
	///
	/// The animate phase eliminates ordering conflicts by always resetting each view before
	/// applying effects. Controllers are iterated in z-index order (bottom to top), so each
	/// view first applies its own contentTransition, then higher controllers apply moveToBack
	/// on top. `UIView.animate` only sees the before/after states, not intermediate resets.
	///
	/// - Parameters:
	///   - additionalPrepare: Called at the end of the prepare phase. Use to set up any state
	///     that cannot be expressed via environment keys.
	///   - additionalAnimation: Called on every progress update inside the animation block.
	///     Runs in the same `UIView.animate` batch as the built-in transitions.
	///   - completion: Called after the transition finishes. `completed` is `false` when the
	///     transition was cancelled (e.g. interactive gesture reversed).
	// @ai-generated(paired)
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

				guard context.isChangingController else { return }
				prepareInsertionTransition(context: context)
				prepareBackground(context: context)
				additionalPrepare?(context)
				// Snap to start state so the view is in its pre-animation position
				// (e.g. off-screen for a slide-up transition) before the animation block runs.
				animateOwn(context: context, progress: context.direction.at(.start), animation: additionalAnimation)
			},
			animation: { context in
				// Reset this view to identity by undoing any previously applied effects
				// (own contentTransition + moveToBack from controllers above).
				// This is safe inside UIView.animate — only the final state matters.
				resetView(context: context)

				// Changing controllers animate to their end state (e.g. slide off-screen).
				// Remaining controllers animate to "fully inserted" — they stay in place.
				let ownProgress: Progress = context.isChangingController ? context.direction.at(.end) : .insertion(1)
				animateOwn(context: context, progress: ownProgress, animation: additionalAnimation)

				// Apply moveToBack effects on views below this controller in the stack.
				// Only if this controller stays in the stack — departing controllers
				// should not push others back.
				// Progress is always insertion(1) = "fully pushed to back" since these
				// controllers are in the final (to) stack and won't animate further.
				applyBackEffects(context: context, progress: .insertion(1))

				if context.isTopController {
					// do we need this? ios seems to update the status bar automatically, need to figure out if there are ios versions that don't do this or if there are edge cases where it doesn't work
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

/// Ordered list of all transitions applied to a single view.
/// Own contentTransition is always first, followed by moveToBack effects
/// from controllers above. This ordering is enforced by the API:
/// `setOwn` must be called before `addBackEffect`.
///
/// `reset` undoes all effects in reverse order, returning the view to identity.
// @ai-generated(paired)
struct ViewTransitions {

	private(set) var all: [UITransition<UIView>] = []
	private var ownCount = 0

	/// Sets the view's own content transition (always first in the list).
	/// Replaces any previously set own transition.
	mutating func setOwn(_ transition: UITransition<UIView>) {
		if ownCount > 0 {
			all[0] = transition
		} else {
			all.insert(transition, at: 0)
			ownCount = 1
		}
	}

	/// The view's own content transition, if set.
	var own: UITransition<UIView>? {
		ownCount > 0 ? all[0] : nil
	}

	/// Appends a moveToBack effect (applied after own transition).
	mutating func addBackEffect(_ transition: UITransition<UIView>) {
		all.append(transition)
	}

	/// Undoes all effects in reverse application order, returning view to identity.
	func reset(view: UIView) {
		for transition in all.reversed() {
			transition.setInitialState(view: view)
		}
	}

	/// Clears all stored transitions.
	mutating func removeAll() {
		all.removeAll()
		ownCount = 0
	}
}

extension UIPresentation.Context {

	/// Per-view cache of all transitions. Keyed by view because all contexts
	/// created via `context.for(vc)` share the same `Cache` instance.
	/// Rebuilt each animate cycle: reset → apply own → apply back effects from above.
	private var allViewTransitions: [Weak<UIView>: ViewTransitions] {
		get { cache[\.allViewTransitions] ?? [:] }
		nonmutating set { cache[\.allViewTransitions] = newValue }
	}

	/// Shortcut to access `ViewTransitions` for this controller's view.
	var viewTransitions: ViewTransitions {
		get { allViewTransitions[view] ?? ViewTransitions() }
		nonmutating set { allViewTransitions[view] = newValue }
	}
}

private extension UIPresentation.Transition {

    /// Configures the content transition for the view being inserted or removed.
    /// Stores it as the `own` transition in `viewTransitions`.
    static func prepareInsertionTransition(context: UIPresentation.Context) {
        let view = context.view
        let currentOwn = context.viewTransitions.own
        var transition: UITransition<UIView>
        if context.needAnimate {
            transition = context.environment.contentTransition(context)
        } else if currentOwn != nil {
            // Not animated but has a prior transition — snap to fully inserted
            // so the view doesn't appear mid-transition when stack is rebuilt without animation.
            transition = context.environment.contentTransition(context).constant(at: .insertion(1))
        } else {
            return
        }
        transition.beforeTransition(view: view)
        context.viewTransitions.setOwn(transition)
    }

    /// Resets this view to identity by undoing all stored effects (back effects
    /// in reverse order, then own), then clears the list. After reset the view
    /// is in identity state — `animateOwn` will recreate the own transition
    /// with fresh initial states captured from this clean state.
    // @ai-generated(paired)
    static func resetView(context: UIPresentation.Context) {
        let view = context.view
        #if VDPRESENT_LOG
        let before = fmt(view)
        #endif
        context.viewTransitions.reset(view: view)
        context.viewTransitions.removeAll()
        #if VDPRESENT_LOG
        print("🔄 reset  vc=\(viewId(context.viewController)), \(before) → \(fmt(view))")
        #endif
    }

    /// Applies this controller's own content transition to `progress`.
    /// After reset, the view is in identity — a fresh transition is created
    /// capturing identity as initial state, then driven to `progress`.
    // @ai-generated(paired)
    static func animateOwn(
        context: UIPresentation.Context,
        progress: Progress,
        animation: ((UIPresentation.Context, Progress) -> Void)?
    ) {
        let view = context.view
        #if VDPRESENT_LOG
        let before = fmt(view)
        #endif
        var transition = context.environment.contentTransition(context)
        // Capture current (identity) state as initial for this transition.
        transition.beforeTransition(view: view)
        transition.update(progress: progress, view: view)
        context.viewTransitions.setOwn(transition)
        #if VDPRESENT_LOG
        print("⚡ animate  vc=\(viewId(context.viewController)), \(before) → \(fmt(view))  @\(progress)")
        #endif
        if let bgView = context.backgroundView {
            context.backgroundTransitions[bgView]?.update(progress: progress, view: bgView)
        }
        animation?(context, progress)
    }

    /// Applies moveToBack effects from this controller onto all visible views below it.
    /// Each back view's current state (already set by its own contentTransition) becomes
    /// the initial state for the moveToBack transition, making effects composable.
    /// The applied transitions are stored in each back view's `viewTransitions.backEffects`
    /// so they can be undone by `resetView` in the next cycle.
    ///
    /// Called only for controllers that remain in the `to` stack — departing controllers
    /// should not push views behind them.
    // @ai-generated(paired)
    static func applyBackEffects(context: UIPresentation.Context, progress: Progress) {
        let toStack = context.viewControllers.to
        guard let myIndex = toStack.firstIndex(of: context.viewController), myIndex > 0 else { return }

        let backControllers = toStack[..<myIndex].reversed()
        for (index, vc) in backControllers.enumerated() {
            let backContext = context.for(vc)
            let backView = backContext.view
            guard !backView.isHidden else { continue }
            let depthIndex = index + 1
            var transition = context.environment.moveToBackTransition(depthIndex, context).reversed
            // Capture current state (after own contentTransition + any earlier back effects)
            // as initial, so this moveToBack composes on top rather than overwriting.
            transition.beforeTransition(view: backView)
            #if VDPRESENT_LOG
            let before = fmt(backView)
            #endif
            transition.update(progress: progress, view: backView)
            // Store so resetView can undo this effect next cycle.
            var vt = backContext.viewTransitions
            vt.addBackEffect(transition)
            backContext.viewTransitions = vt
            #if VDPRESENT_LOG
            if progress.value == 0 || progress.value == 1 {
                print("⚡ backEffect  vc=\(viewId(context.viewController)) → \(viewName(backView)) depth=\(depthIndex), \(before) → \(fmt(backView))  @\(progress)")
            }
            #endif
        }
    }

    /// Resets all transitions and clears cache for controllers being removed from the stack.
    // @ai-generated(paired)
    static func cleanupTransitions(context: UIPresentation.Context) {
        guard context.viewControllers.toRemove.contains(context.viewController) else { return }
        let view = context.view
        #if VDPRESENT_LOG
        print("🔴 cleanup  vc=\(viewId(context.viewController))")
        #endif
        context.viewTransitions.reset(view: view)
        context.viewTransitions.removeAll()
    }

    // MARK: - Debug helpers

    #if VDPRESENT_LOG
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
    #endif

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
