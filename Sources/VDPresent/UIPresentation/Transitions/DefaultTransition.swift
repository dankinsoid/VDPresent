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
	/// - **prepare** — reset to identity, build before/after transition sets,
	///   apply the before-state transitions so views start at the correct pre-animation position.
	/// - **animate** — apply the after-state transitions. UIKit animates from the
	///   before-state (on model layer) to the after-state.
	/// - **completion** — state reset/cleanup, container visibility, `completion` callback
	///
	/// Before and after transition sets can differ (e.g. different recess effects
	/// depending on which controllers are present), unlike the previous model
	/// where a single transition was driven by two progress values.
	///
	/// - Parameters:
	///   - additionalPrepare: Called at the end of the prepare phase. Use to set up any state
	///     that cannot be expressed via environment keys.
	///   - additionalAnimation: Called on every progress update inside the animation block.
	///     Runs in the same `UIView.animate` batch as the built-in transitions.
	///   - completion: Called after the transition finishes. `completed` is `false` when the
	///     transition was cancelled (e.g. interactive gesture reversed).
	/// @ai-generated(solo)
	static func base(
		transitionID: AnyHashable,
		additionalPrepare: ((UIPresentation.Context) -> Void)? = nil,
		additionalAnimation: ((UIPresentation.Context, Progress) -> Void)? = nil,
		completion: ((UIPresentation.Context, Bool) -> Void)? = nil
	) -> UIPresentation.Transition {
		UIPresentation.Transition(
			transitionID: transitionID,
			prepare: { context in
				// Reset is done externally (UIStackController resets all views
				// before calling prepare) so that all views are in identity/layout
				// position when recessTransitions read target frames.

				if context.isChangingController {
					prepareBackground(context: context)
					additionalPrepare?(context)
				} else if context.backgroundView == nil {
					prepareBackground(context: context)
				}

				// Build before/after transition sets and apply the before-state.
				buildTransitions(context: context, animation: additionalAnimation)
			},
			animation: { context in
				// Apply the after-state transitions.
				// UIKit animates from before-state to after-state.
				context.viewTransitions.applyAfter(view: context.view)
				if let bgView = context.backgroundView {
					context.backgroundTransitions[bgView]?.update(progress: .insertion(1), view: bgView)
				}
				additionalAnimation?(context, .insertion(1))

				if context.isTopController {
					context.updateStatusBar(style: context.viewController.preferredStatusBarStyle)
				}
			},
			completion: { context, completed in
				let finalContext = completed ? context : context.reversed
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

/// Holds two separate combined transitions for a single view:
/// `before` — the visual state before the animation starts,
/// `after`  — the visual state at the end of the animation.
///
/// Both are built from identity (layout position). The prepare phase applies
/// `before`; the animation block applies `after`. This replaces the previous
/// single-transition-with-progress model so that before/after can use
/// genuinely different transition sets (e.g. different recess effects when
/// a controller is being added or removed).
/// @ai-generated(solo)
struct ViewTransitions {

	/// Transition representing the pre-animation visual state.
	private(set) var before: UITransition<UIView>?

	/// Transition representing the post-animation visual state.
	private(set) var after: UITransition<UIView>?

	/// Builds the before-state transition from the given sub-transitions,
	/// captures identity from the view (which must be in identity state),
	/// and applies the transition at full progress.
	mutating func buildBefore(
		_ transitions: [UITransition<UIView>],
		view: UIView
	) {
		var merged = UITransition<UIView>.combined(transitions)
		merged.beforeTransition(view: view)
		merged.update(progress: .insertion(1), view: view)
		before = merged
	}

	/// Builds the after-state transition. Reuses identity captured by `before`
	/// if the modifiers match; otherwise captures fresh identity from the view.
	mutating func buildAfter(
		_ transitions: [UITransition<UIView>],
		view: UIView
	) {
		var merged = UITransition<UIView>.combined(transitions)
		merged.beforeTransitionIfNeeded(view: view, current: before)
		after = merged
	}

	/// Applies the after-state transition at full progress.
	/// Called inside the animation block.
	func applyAfter(view: UIView) {
		after?.update(progress: .insertion(1), view: view)
	}

	/// Resets the view to identity using whichever transition has captured it.
	func reset(view: UIView) {
		let source = before ?? after
		source?.setInitialState(view: view)
	}

	/// Clears both transitions.
	mutating func removeAll() {
		before = nil
		after = nil
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

	/// Resets this view to identity by undoing the stored transition,
	/// then clears stored state.
	/// @ai-generated(guided)
	static func resetView(context: UIPresentation.Context) {
		let view = context.view
		context.viewTransitions.reset(view: view)
		context.viewTransitions.removeAll()
	}

	/// Collects transitions representing the visual state **before** the animation.
	///
	/// For an insertion (push): the new controller is off-screen, back views have
	/// no recess effects from the new controller yet (only from controllers that
	/// were already above them).
	///
	/// For a removal (pop): the departing controller is still on-screen, back views
	/// still have recess effects from the departing controller.
	/// @ai-generated(solo)
	static func collectBeforeTransitions(
		context: UIPresentation.Context
	) -> [UITransition<UIView>] {
		var transitions: [UITransition<UIView>] = []

		// Own contentTransition — only for changing, non-frozen controllers.
		if context.isChangingController && !context.isBehindFrozen {
			transitions.append(context.environment.contentTransition(context))
		}

		// Recess effects from controllers that were above **before** the change.
		// "from" controllers represent the pre-animation stack.
		let fromControllers = context.visibleViewControllers.from
		if let myIndex = fromControllers.firstIndex(of: context.viewController) {
			let frontControllers = fromControllers[(myIndex + 1)...]
			for (offset, frontVC) in frontControllers.enumerated() {
				let frontContext = context.for(frontVC)
				let depthIndex = offset + 1
				let backTransition = frontContext.environment.recessTransition(depthIndex, frontContext).reversed
				transitions.append(backTransition)
				if frontContext.environment.backEffectBarrier {
					break
				}
			}
		}

		return transitions
	}

	/// Collects transitions representing the visual state **after** the animation.
	///
	/// For an insertion (push): the new controller is on-screen, back views have
	/// recess effects from the new controller.
	///
	/// For a removal (pop): the departing controller is off-screen, back views no
	/// longer have recess effects from the departing controller.
	/// @ai-generated(solo)
	static func collectAfterTransitions(
		context: UIPresentation.Context
	) -> [UITransition<UIView>] {
		var transitions: [UITransition<UIView>] = []

		// Own contentTransition — only for changing, non-frozen controllers.
		if context.isChangingController && !context.isBehindFrozen {
			transitions.append(context.environment.contentTransition(context))
		}

		// Recess effects from controllers that will be above **after** the change.
		// "to" controllers represent the post-animation stack.
		let toControllers = context.visibleViewControllers.to
		if let myIndex = toControllers.firstIndex(of: context.viewController) {
			let frontControllers = toControllers[(myIndex + 1)...]
			for (offset, frontVC) in frontControllers.enumerated() {
				let frontContext = context.for(frontVC)
				let depthIndex = offset + 1
				let backTransition = frontContext.environment.recessTransition(depthIndex, frontContext).reversed
				transitions.append(backTransition)
				if frontContext.environment.backEffectBarrier {
					break
				}
			}
		}

		return transitions
	}

	/// Builds both before and after transitions for a view.
	///
	/// 1. Collects before-state transitions and builds them (captures identity, applies).
	/// 2. Collects after-state transitions and builds them (reuses identity from before).
	/// 3. Applies the before-state so the view starts in the correct pre-animation position.
	/// @ai-generated(solo)
	static func buildTransitions(
		context: UIPresentation.Context,
		animation: ((UIPresentation.Context, Progress) -> Void)?
	) {
		let view = context.view

		// 1. Before-state: capture identity, apply.
		let beforeTransitions = collectBeforeTransitions(context: context)
		context.viewTransitions.buildBefore(beforeTransitions, view: view)

		// 2. After-state: reuse identity from before.
		let afterTransitions = collectAfterTransitions(context: context)
		context.viewTransitions.buildAfter(afterTransitions, view: view)

		#if VDPRESENT_LOG
		let vcName = view.accessibilityIdentifier ?? "?"
		print("[buildTransitions] \(vcName): before=\(beforeTransitions.count) parts, after=\(afterTransitions.count) parts, isChanging=\(context.isChangingController)")
		#endif

		// 3. Background view — apply before-state.
		if let bgView = context.backgroundView {
			context.backgroundTransitions[bgView]?.update(progress: .insertion(0), view: bgView)
		}
		animation?(context, .insertion(0))
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
