import UIKit
import VDTransition

public extension UIPresentation.Transition {

	/// Base transition that orchestrates the full presentation lifecycle: insertion animation,
	/// recess animation for views below, background view, status bar, and cleanup.
	///
	/// All visual behaviour is configured via environment keys — call `.environment(...)` on the
	/// result to set `contentTransition`, `recessTransition`, `contentLayout`, etc.
	///
	/// Three lifecycle phases, executed in order:
	/// - **prepare** — reset to identity, then apply pre-animation state (own + back effects)
	/// - **animate** — reset to identity, then apply post-animation state (own + back effects)
	/// - **completion** — state reset/cleanup, container visibility, `completion` callback
	///
	/// Both prepare and animate follow the same pattern: reset → apply own → apply back effects.
	/// The only difference is the progress value. `UIView.animate` sees the prepare state as
	/// "before" and the animate state as "after".
	///
	/// - Parameters:
	///   - additionalPrepare: Called at the end of the prepare phase. Use to set up any state
	///     that cannot be expressed via environment keys.
	///   - additionalAnimation: Called on every progress update inside the animation block.
	///     Runs in the same `UIView.animate` batch as the built-in transitions.
	///   - completion: Called after the transition finishes. `completed` is `false` when the
	///     transition was cancelled (e.g. interactive gesture reversed).
	/// @ai-generated(guided)
	static func base(
		transitionID: AnyHashable,
		additionalPrepare: ((UIPresentation.Context) -> Void)? = nil,
		additionalAnimation: ((UIPresentation.Context, Progress) -> Void)? = nil,
		completion: ((UIPresentation.Context, Bool) -> Void)? = nil
	) -> UIPresentation.Transition {
		UIPresentation.Transition(
			transitionID: transitionID,
			prepare: { context in
				let progress = prepareProgress(context: context)

				// Reset to identity, then apply the pre-animation state.
				resetView(context: context)

				if context.isChangingController {
					prepareInsertionTransition(context: context)
					prepareBackground(context: context)
					additionalPrepare?(context)
				} else if context.backgroundView == nil {
					// Re-entered visible zone: container was recreated but
					// background view was lost — recreate it.
					prepareBackground(context: context)
				}

				animateOwn(context: context, progress: progress, animation: additionalAnimation)
				applyBackEffects(context: context, progress: progress)
			},
			animation: { context in
				let progress = animateProgress(context: context)

				// Reset to identity, then apply the post-animation state.
				resetView(context: context)
				#if VDPRESENT_LOG
				let vcName = context.viewController.view.accessibilityIdentifier ?? "?"
				let v = context.view
				let pL = v.layer.presentation()
				let modelT = v.affineTransform
				let presT = pL?.affineTransform() ?? modelT
				let presFrame = pL?.frame ?? v.frame
				print("[in-animate-after-reset] \(vcName): model=\(modelT.shortDesc) pres=\(presT.shortDesc) presFrame.minY=\(Int(presFrame.minY))")
				#endif
				animateOwn(context: context, progress: progress, animation: additionalAnimation)
				applyBackEffects(context: context, progress: progress)

				if context.isTopController {
					context.updateStatusBar(style: context.viewController.preferredStatusBarStyle)
				}
			},
			completion: { context, completed in
				let finalContext = completed ? context : context.reversed
//				cleanupTransitions(context: finalContext)
//				if finalContext.needHide {
//					finalContext.container.isHidden = true
//				}
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
	var recessTransition: (Int, UIPresentation.Context) -> UITransition<UIView> {
		get { self[\.recessTransition] ?? { _, _ in .identity } }
		set { self[\.recessTransition] = newValue }
	}

	/// Layout constraints applied to the presented view's container. Default: `.fill`.
	var contentLayout: ContentLayout {
		get { self[\.contentLayout] ?? .fill }
		set { self[\.contentLayout] = newValue }
	}

	/// Whether this presentation renders over the current context (like a sheet) rather than
	/// replacing it. Affects how the view hierarchy is structured. Default: `false`.
	var overCurrentContext: Bool {
		get { self[\.overCurrentContext] ?? false }
		set { self[\.overCurrentContext] = newValue }
	}

	/// When `true`, this controller acts as a barrier for back effects from above.
	/// `applyBackEffects` stops iterating downward when it hits a barrier controller.
	/// This prevents effects from accumulating across same-type presentations
	/// (e.g. two pushes both offsetting the same root view). Default: `false`.
	var backEffectBarrier: Bool {
		get { self[\.backEffectBarrier] ?? false }
		set { self[\.backEffectBarrier] = newValue }
	}

	/// Controls how controllers behind the top animate during a stack change.
	///
	/// - `freeze`: All behind-controllers stay in place; the top controller
	///   simply slides over them. Like UINavigationController push. **(default)**
	/// - `animate`: All behind departing/arriving controllers play their own
	///   reverse contentTransition animation.
	/// - `freezeMatching`: Behind-controllers with the same `transitionID` as the top
	///   are frozen (moved only via backEffect); controllers with a different
	///   `transitionID` play their own animation.
	var behindBehavior: BehindBehavior {
		get { self[\.behindBehavior] ?? .freeze }
		set { self[\.behindBehavior] = newValue }
	}
}

/// Controls how controllers behind the top animate during a transition.
public enum BehindBehavior {

	/// All behind-controllers are frozen — no own animation, only backEffect.
	case freeze

	/// All behind departing/arriving controllers animate their own contentTransition.
	case animate

	/// Behind-controllers with the same `transitionID` as the top are frozen;
	/// controllers with a different `transitionID` play their own animation.
	case freezeMatching
}

/// Ordered list of all transitions applied to a single view.
/// Own contentTransition is always first, followed by recess effects
/// from controllers above. This ordering is enforced by the API:
/// `setOwn` must be called before `addBackEffect`.
///
/// `reset` undoes all effects in reverse order, returning the view to identity.
/// @ai-generated(guided)
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

	/// Appends a recess effect (applied after own transition).
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

	/// Progress for the prepare phase (pre-animation state).
	///
	/// - Remaining / frozen behind: `.insertion(1)` — fully appeared, no own animation.
	///   Frozen controllers sit in place and are moved only by back effects from above.
	/// - Top / animating controller: `ownDirection.at(.start)` — animation start point.
	/// @ai-generated(solo)
	static func prepareProgress(context: UIPresentation.Context) -> Progress {
		if !context.isChangingController || context.isBehindFrozen {
			return .insertion(1)
		}
		return context.ownDirection.at(.start)
	}

	/// Progress for the animate phase (post-animation state).
	///
	/// - Remaining controllers: `.insertion(1)` — stay fully appeared.
	/// - Frozen behind: `.insertion(1)` — stay fully appeared, moved only by back effects.
	/// - Top / animating controller: `ownDirection.at(.end)` — animation end point.
	/// @ai-generated(solo)
	static func animateProgress(context: UIPresentation.Context) -> Progress {
		if !context.isChangingController || context.isBehindFrozen {
			return .insertion(1)
		}
		return context.ownDirection.at(.end)
	}

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
	/// @ai-generated(guided)
	static func resetView(context: UIPresentation.Context) {
		let view = context.view
		context.viewTransitions.reset(view: view)
		context.viewTransitions.removeAll()
	}

	/// Applies this controller's own content transition to `progress`.
	/// After reset, the view is in identity — a fresh transition is created
	/// capturing identity as initial state, then driven to `progress`.
	/// @ai-generated(guided)
	static func animateOwn(
		context: UIPresentation.Context,
		progress: Progress,
		animation: ((UIPresentation.Context, Progress) -> Void)?
	) {
		let view = context.view
		var transition = context.environment.contentTransition(context)
		// Capture current (identity) state as initial for this transition.
		transition.beforeTransitionIfNeeded(view: view)
		transition.update(progress: progress, view: view)
		context.viewTransitions.setOwn(transition)
		if let bgView = context.backgroundView {
			context.backgroundTransitions[bgView]?.update(progress: progress, view: bgView)
		}
		animation?(context, progress)
	}

	/// Applies recess effects from this controller onto all visible views below it
	/// in the `all()` iteration order (which includes both `to` and departing controllers).
	///
	/// Each back view's current state (already set by its own contentTransition) becomes
	/// the initial state for the recess transition, making effects composable.
	/// The applied transitions are stored in each back view's `viewTransitions.backEffects`
	/// so they can be undone by `resetView` in the next cycle.
	///
	/// Stops at a controller with `backEffectBarrier == true` — it owns back effects
	/// for everything below it.
	/// @ai-generated(guided)
	static func applyBackEffects(context: UIPresentation.Context, progress: Progress) {
		// Use visible controllers so barriers from non-visible departing VCs
		// don't block recess propagation to re-entering controllers (e.g. pop-to-root).
		let allControllers = context.visibleViewControllers.all(context.direction)
		guard let myIndex = allControllers.firstIndex(of: context.viewController), myIndex > 0 else { return }

		let backControllers = allControllers[..<myIndex].reversed()
		let toRemove = context.viewControllers.toRemove
		for (index, vc) in backControllers.enumerated() {
			let backContext = context.for(vc)
			let backView = backContext.view
			guard !backView.isHidden else { continue }
			let depthIndex = index + 1
			var transition = context.environment.recessTransition(depthIndex, context).reversed
			// Capture current state (after own contentTransition + any earlier back effects)
			// as initial, so this recess composes on top rather than overwriting.
			transition.beforeTransitionIfNeeded(view: backView)
			// When both source and target are departing, keep recess locked
			// so the back view slides off-screen at its current scale instead
			// of un-recessing (which causes a visible scale-up flash).
			let effectProgress = toRemove.contains(vc) ? .insertion(1) : progress
			transition.update(progress: effectProgress, view: backView)
			// Store so resetView can undo this effect next cycle.
			backContext.viewTransitions.addBackEffect(transition)

			// Stop at a barrier — it owns back effects for everything below.
			if backContext.environment.backEffectBarrier {
				break
			}
		}
	}

	/// Resets all transitions and clears cache for controllers being removed from the stack.
	/// @ai-generated(guided)
	static func cleanupTransitions(context: UIPresentation.Context) {
		guard context.viewControllers.toRemove.contains(context.viewController) else { return }
		let view = context.view
		context.viewTransitions.reset(view: view)
		context.viewTransitions.removeAll()
	}

	// MARK: - Debug helpers

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
			if context.environment.backgroundPlacement == .behindController {
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

#if VDPRESENT_LOG
extension CGAffineTransform {

	var shortDesc: String {
		let sx = sqrt(a * a + c * c)
		let sy = sqrt(b * b + d * d)
		var parts: [String] = []
		if tx != 0 { parts.append("tx=\(Int(tx))") }
		if ty != 0 { parts.append("ty=\(Int(ty))") }
		if abs(sx - 1) > 0.001 || abs(sy - 1) > 0.001 {
			parts.append("sx=\(String(format: "%.3f", sx))")
		}
		return parts.isEmpty ? "identity" : parts.joined(separator: " ")
	}
}
#endif
