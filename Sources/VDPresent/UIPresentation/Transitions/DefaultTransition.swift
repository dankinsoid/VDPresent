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
	/// - **prepare** — reset to identity, build transitions (capturing identity as initial state),
	///   then apply pre-animation state via `update(prepareProgress)`
	/// - **animate** — NO reset. Reuse transitions from prepare, call `update(animateProgress)`.
	///   UIKit animates from the prepare state (on model layer) to the animate state.
	/// - **completion** — state reset/cleanup, container visibility, `completion` callback
	///
	/// The prepare phase resets and rebuilds; the animate phase only updates progress.
	/// This avoids writing identity to the model layer inside `UIView.animate`, which
	/// would cause intermediate views to flash at full size before sliding away.
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

				// Reset to identity so buildTransitions captures clean initial state.
				resetView(context: context)

				if context.isChangingController {
					prepareBackground(context: context)
					additionalPrepare?(context)
				} else if context.backgroundView == nil {
					prepareBackground(context: context)
				}

				// Collect own + back effects from above, combine, apply prepareProgress.
				buildTransitions(context: context, progress: progress, animation: additionalAnimation)
			},
			animation: { context in
				let progress = animateProgress(context: context)

				// No reset — update the combined transition built during prepare.
				// UIKit animates from prepare state to this animate state.
				context.viewTransitions.combined?.update(progress: progress, view: context.view)
				if let bgView = context.backgroundView {
					context.backgroundTransitions[bgView]?.update(progress: progress, view: bgView)
				}
				additionalAnimation?(context, progress)

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

/// Combined transition for a single view — own contentTransition merged with
/// all recess effects from controllers above via `.combined()`.
///
/// Using `combined` instead of applying transitions sequentially ensures that
/// conflicting properties (e.g. two transforms) compose correctly rather than
/// the last write winning.
///
/// After `buildCombined`, a single `update(progress:)` drives all sub-transitions.
/// @ai-generated(guided)
struct ViewTransitions {

	/// The merged transition. Built once per prepare phase.
	private(set) var combined: UITransition<UIView>?

	/// Number of sub-transitions that were combined. Used for diagnostics.
	private(set) var layerCount = 0

	/// Builds a combined transition from own + back effects, captures identity
	/// from the view (which must be in identity state), and applies `progress`.
	mutating func build(
		_ transitions: [UITransition<UIView>],
		view: UIView,
		progress: Progress
	) {
		layerCount = transitions.count
		var merged = UITransition<UIView>.combined(transitions)
		merged.beforeTransition(view: view)
		merged.update(progress: progress, view: view)
		combined = merged
	}

	/// Resets the view to identity using the combined transition's initial state.
	func reset(view: UIView) {
		combined?.setInitialState(view: view)
	}

	/// Clears the combined transition.
	mutating func removeAll() {
		combined = nil
		layerCount = 0
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

	/// Resets this view to identity by undoing the combined transition,
	/// then clears stored state.
	/// @ai-generated(guided)
	static func resetView(context: UIPresentation.Context) {
		let view = context.view
		context.viewTransitions.reset(view: view)
		context.viewTransitions.removeAll()
	}

	/// Collects own contentTransition + recess effects from all controllers above
	/// this one, combines them into a single transition, captures identity state,
	/// and applies `progress`.
	///
	/// Each VC collects effects **from above** (front → back), so all sub-transitions
	/// for this view are gathered in one place. `.combined()` merges conflicting
	/// properties (e.g. two transforms) correctly.
	///
	/// Back effects from departing controllers onto departing back views are made
	/// `.constant(at:)` so they stay recessed regardless of this view's progress.
	/// @ai-generated(solo)
	static func buildTransitions(
		context: UIPresentation.Context,
		progress: Progress,
		animation: ((UIPresentation.Context, Progress) -> Void)?
	) {
		let view = context.view
		var transitions: [UITransition<UIView>] = []

		// 1. Own contentTransition.
		let ownTransition = context.environment.contentTransition(context)
		transitions.append(ownTransition)

		// 2. Recess effects from controllers above this one.
		let allControllers = context.visibleViewControllers.all(context.direction)
		if let myIndex = allControllers.firstIndex(of: context.viewController) {
			let frontControllers = allControllers[(myIndex + 1)...]
			let toRemove = context.viewControllers.toRemove
			let isDeparting = toRemove.contains(context.viewController)
			for (offset, frontVC) in frontControllers.enumerated() {
				let frontContext = context.for(frontVC)
				let depthIndex = offset + 1
				var backTransition = frontContext.environment.recessTransition(depthIndex, frontContext).reversed
				// Departing back views must stay recessed — use constant so
				// the recess effect doesn't animate toward identity when
				// this view's progress moves toward removal.
				if isDeparting {
					backTransition = backTransition.constant(at: .insertion(0))
				}
				transitions.append(backTransition)

				// Barrier: this front VC owns everything below — stop collecting.
				if frontContext.environment.backEffectBarrier {
					break
				}
			}
		}

		// 3. Combine, capture identity, apply progress.
		#if VDPRESENT_LOG
		let vcName = view.accessibilityIdentifier ?? "?"
		print("[buildTransitions] \(vcName): \(transitions.count) parts, progress=\(progress), isDeparting=\(context.viewControllers.toRemove.contains(context.viewController)), isChanging=\(context.isChangingController)")
		#endif
		context.viewTransitions.build(transitions, view: view, progress: progress)

		// 4. Background view.
		if let bgView = context.backgroundView {
			context.backgroundTransitions[bgView]?.update(progress: progress, view: bgView)
		}
		animation?(context, progress)
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
