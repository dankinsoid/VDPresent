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

				prepareBackground(context: context)
				// Collect own + back effects from above, combine, apply prepareProgress.
				buildTransitions(context: context, progress: progress, animation: additionalAnimation)

				additionalPrepare?(context)
			},
			animation: { context in
				let progress = animateProgress(context: context)

				// No reset — update the combined transition built during prepare.
				// UIKit animates from prepare state to this animate state.
				let identityState = context.viewTransitions.state.identity
				let newState = context.viewTransitions.tween?.to(context.view, identityState)
				newState?.apply(to: context.view)
				context.viewTransitions.state = newState ?? identityState
				context.viewTransitions.progress = progress
				if let bgView = context.backgroundView {
					let bgID = ObjectIdentifier(bgView)
					if var bgTx = context.backgroundTransitions[bgID] {
						let identityState = bgTx.state.identity
						let newState = bgTx.tween?.to(bgView, identityState)
						newState?.apply(to: bgView)
						bgTx.state = newState ?? identityState
						bgTx.progress = progress
						context.backgroundTransitions[bgID] = bgTx
					}
				}
				additionalAnimation?(context, progress)

				if context.isTopController {
					context.updateStatusBar(style: context.viewController.preferredStatusBarStyle)
				}
			},
			completion: { context, completed in
				let finalContext = completed ? context : context.reversed
				settleViewState(context: context, completed: completed)
				completeBackground(context: finalContext)
				completion?(context, completed)
			}
		)
	}
}

public extension UIPresentation.Environment {

	/// Animation applied to the incoming view. Default: `.identity` (no animation).
	var contentTransition: (UIPresentation.Context) -> UIViewTransition {
		get { self[\.contentTransition] ?? { _ in .identity } }
		set { self[\.contentTransition] = newValue }
	}

	/// Animation applied to views moving to the back when a new VC becomes top.
	/// `Int` is the depth index (1 = immediate predecessor, 2 = one below, …). Default: `.identity`.
	var recessTransition: (Int, UIPresentation.Context) -> UIViewTransition {
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
struct ViewTransitions {

	var viewID: ObjectIdentifier?
	/// The merged transition. Built once per prepare phase.
	var tween: UIViewTransition.Tween?
	var state = UIViewState()
	/// Pre-animation snapshot for rollback on cancel.
	var oldState = UIViewState()
	/// Clean end state: computed without barrier/departing workarounds.
	var cleanTo: UIViewTransition.Tween?
	var progress: Progress = .insertion(0)

	/// Clears the combined transition.
	mutating func removeAll() {
		tween = nil
	}
}

extension UIPresentation.Context {

	/// Per-view cache of all transitions. Keyed by view because all contexts
	/// created via `context.for(vc)` share the same `Cache` instance.
	/// Rebuilt each animate cycle: reset → apply own → apply back effects from above.
	private var allViewTransitions: [ObjectIdentifier: ViewTransitions] {
		get { cache[\.allViewTransitions] ?? [:] }
		nonmutating set { cache[\.allViewTransitions] = newValue }
	}

	/// Shortcut to access `ViewTransitions` for this controller's view.
	var viewTransitions: ViewTransitions {
		get { allViewTransitions[ObjectIdentifier(viewController)] ?? ViewTransitions() }
		nonmutating set { allViewTransitions[ObjectIdentifier(viewController)] = newValue }
	}

	var isNewView: Bool {
		viewTransitions.viewID != ObjectIdentifier(view)
	}
}

private extension UIPresentation.Transition {

	/// Progress for the prepare phase (pre-animation state).
	///
	/// All controllers share the same progress direction — derived from the
	/// overall transition direction. This lets back effects animate in sync
	/// with the top controller via a single combined transition.
	///
	/// - Insertion: `.insertion(0)` — animation starts at "not yet inserted".
	/// - Removal: `.insertion(1)` — animation starts at "fully inserted".
	/// @ai-generated(solo)
	static func prepareProgress(context: UIPresentation.Context) -> Progress {
		context.direction == .insertion ? .insertion(0) : .insertion(1)
	}

	/// Progress for the animate phase (post-animation state).
	///
	/// - Insertion: `.insertion(1)` — animation ends at "fully inserted".
	/// - Removal: `.insertion(0)` — animation ends at "not yet inserted" (removed).
	/// @ai-generated(solo)
	static func animateProgress(context: UIPresentation.Context) -> Progress {
		context.direction == .insertion ? .insertion(1) : .insertion(0)
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
	@MainActor
	static func buildTransitions(
		context: UIPresentation.Context,
		progress: Progress,
		animation: ((UIPresentation.Context, Progress) -> Void)?
	) {
		var from: [UIViewTransition.TransitionClosure] = []
		var to: [UIViewTransition.TransitionClosure] = []
		// Clean end state: own content + recess from final (to) stack.
		var cleanTo: [UIViewTransition.TransitionClosure] = []

		// Background transition — built alongside the view using the same conditions.
		let backgroundView = context.backgroundView
		let bgTransition = context.environment.backgroundTransition
		let hasBg = backgroundView != nil && !bgTransition.isIdentity
		var bgFrom: [UIViewTransition.TransitionClosure] = []
		var bgTo: [UIViewTransition.TransitionClosure] = []

		let allControllers = context.visibleViewControllers.all(context.direction)
		let myIndex = allControllers.firstIndex(of: context.viewController)

		// 1. Own contentTransition.
		let contentTransition = context.environment.contentTransition(context)
		let transition = contentTransition.tween(for: context.ownDirection)
		let bgTween = hasBg ? bgTransition.tween(for: context.ownDirection) : nil

		if context.isNewView {
			if context.isChangingController, !context.isBehindFrozen {
				from.append(transition.from)
				if let bgTween { bgFrom.append(bgTween.from) }
			} else {
				from.append(transition.to)
				if let bgTween { bgFrom.append(bgTween.to) }
			}
		}

		if !context.isBehindFrozen {
			to.append(transition.to)
			if let bgTween { bgTo.append(bgTween.to) }
		}
		cleanTo.append(transition.to)

		// 2. Recess effects from controllers above this one.
		// Background has no recess — only the view accumulates recess effects.
		if let myIndex {
			let frontControllers = allControllers[(myIndex + 1)...]
			for (offset, frontVC) in frontControllers.enumerated() {
				let frontContext = context.for(frontVC)
				let depthIndex = offset + 1
				let backTransition = frontContext.environment.recessTransition(depthIndex, frontContext).tween(for: frontContext.ownDirection)
				let isDeparting = frontContext.ownDirection == .removal

				#if VDPRESENT_LOG
				let myName = context.viewController.view.accessibilityIdentifier ?? String(describing: type(of: context.viewController))
				let frontName = frontVC.view.accessibilityIdentifier ?? String(describing: type(of: frontVC))
				let frontDir = frontContext.ownDirection == .insertion ? "insertion" : "removal"
				var addedTo = false, addedFrom = "", addedCleanTo = false
				#endif

				if !context.isBehindFrozen || frontContext.environment.backEffectBarrier || (context.isNewView && !isDeparting) {
					to.append(backTransition.to)
					#if VDPRESENT_LOG
					addedTo = true
					#endif
				}

				if !isDeparting {
					cleanTo.append(backTransition.to)
					#if VDPRESENT_LOG
					addedCleanTo = true
					#endif
				}

				if frontContext.isChangingController, !frontContext.isBehindFrozen {
					if context.isNewView || !isDeparting {
						from.append(backTransition.from)
						#if VDPRESENT_LOG
						addedFrom = "from(willAppear)"
						#endif
					}
				} else if context.isNewView {
					from.append(backTransition.to)
					#if VDPRESENT_LOG
					addedFrom = "from(idle)"
					#endif
				}

				#if VDPRESENT_LOG
				print("  [recess] \(myName) ← \(frontName) dir=\(frontDir) departing=\(isDeparting) changing=\(frontContext.isChangingController) frontFrozen=\(frontContext.isBehindFrozen) barrier=\(frontContext.environment.backEffectBarrier) | to=\(addedTo) from=\(addedFrom.isEmpty ? "none" : addedFrom) cleanTo=\(addedCleanTo) | isNewView=\(context.isNewView) isBehindFrozen=\(context.isBehindFrozen)")
				#endif

				if frontContext.environment.backEffectBarrier {
					break
				}
			}
		}

		var oldState = context.viewTransitions.state
		oldState.snapshot(context.view)

		if context.isBehindFrozen {
			to.insert(
				{ [oldState] _, identity in
					identity.merged(with: oldState)
				},
				at: 0
			)
			// Freeze existing background — keep it at its current visual state.
			// New backgrounds have no meaningful state to freeze (just .clear),
			// so they get bgTween.to instead.
			if hasBg, let backgroundView {
				let bgID = ObjectIdentifier(backgroundView)
				let isExistingBg = context.backgroundTransitions[bgID]?.viewID == bgID
				if isExistingBg {
					var bgOld = context.backgroundTransitions[bgID]!.state
					bgOld.snapshot(backgroundView)
					bgTo.insert(
						{ [bgOld] _, identity in
							identity.merged(with: bgOld)
						},
						at: 0
					)
				} else if let bgTween {
					bgTo.append(bgTween.to)
				}
			}
		}

		let newTransition = UIViewTransition.Tween.combined(from: from, to: to)
		let newState = newTransition.from(context.view, oldState)

		newState.apply(to: context.view)

		context.viewTransitions.tween = newTransition
		context.viewTransitions.cleanTo = UIViewTransition.Tween.combined(from: [], to: cleanTo)
		context.viewTransitions.oldState = oldState
		context.viewTransitions.state = newState
		context.viewTransitions.progress = progress
		context.viewTransitions.viewID = ObjectIdentifier(context.view)

		// Apply background transition.
		if hasBg, let backgroundView {
			let bgID = ObjectIdentifier(backgroundView)
			var bgTransitions = context.backgroundTransitions[bgID] ?? ViewTransitions()

			var bgOldState = bgTransitions.state
			bgOldState.snapshot(backgroundView)

			let bgCombined = UIViewTransition.Tween.combined(from: bgFrom, to: bgTo)
			let bgNewState = bgCombined.from(backgroundView, bgOldState)
			bgNewState.apply(to: backgroundView)

			bgTransitions.tween = bgCombined
			bgTransitions.oldState = bgOldState
			bgTransitions.state = bgNewState
			bgTransitions.progress = progress
			bgTransitions.viewID = ObjectIdentifier(backgroundView)
			context.backgroundTransitions[bgID] = bgTransitions
		}

		animation?(context, progress)
	}

	/// Settles the view into its correct post-animation state.
	/// - completed: applies the clean `to` state (no barrier/departing workarounds).
	/// - cancelled: restores the pre-animation snapshot.
	///
	/// TODO: Verify correctness when view resizes during animation — cleanTo closures
	/// recompute from current bounds at call time, which should be correct, but needs testing.
	/// @ai-generated(solo)
	@MainActor
	static func settleViewState(context: UIPresentation.Context, completed: Bool) {
		if completed {
			let identityState = context.viewTransitions.state.identity
			if let cleanState = context.viewTransitions.cleanTo?.to(context.view, identityState) {
				cleanState.apply(to: context.view)
				context.viewTransitions.state = cleanState
			}
		} else {
			let oldState = context.viewTransitions.oldState
			oldState.apply(to: context.view)
			context.viewTransitions.state = oldState
		}
	}

	// MARK: - Debug helpers

	/// Ensures the background view exists in the hierarchy. Does not build transitions —
	/// that is handled by `buildTransitions` using the same logic as the main view.
	/// No-ops when `backgroundTransition` is `.identity`.
	/// @ai-generated(solo)
	@MainActor
	static func prepareBackground(
		context: UIPresentation.Context
	) {
		let transition = context.environment.backgroundTransition
		guard !transition.isIdentity else {
			#if VDPRESENT_LOG
			print("  [bg] skip \(context.viewController.view.accessibilityIdentifier ?? "?") — identity transition")
			#endif
			return
		}
		guard context.backgroundView == nil else {
			#if VDPRESENT_LOG
			let bgView = context.backgroundView!
			print("  [bg] reuse \(context.viewController.view.accessibilityIdentifier ?? "?") superview=\(bgView.superview != nil) alpha=\(bgView.alpha) hidden=\(bgView.isHidden) color=\(bgView.backgroundColor?.description ?? "nil")")
			#endif
			return
		}
		let backgroundView = UIView()
		backgroundView.backgroundColor = .clear
		backgroundView.isUserInteractionEnabled = false
		context.backgroundView = backgroundView
		#if VDPRESENT_LOG
		print("  [bg] create \(context.viewController.view.accessibilityIdentifier ?? "?") placement=\(context.environment.backgroundPlacement)")
		#endif
		if context.environment.backgroundPlacement == .behindController {
			if let i = context.viewControllers.to.firstIndex(of: context.viewController), i > 0 {
				let vc = context.viewControllers.to[i - 1]
				context.for(vc).view.addSubview(backgroundView, layout: context.environment.backgroundLayout)
			}
		} else {
			context.container.insertSubview(backgroundView, at: 0, layout: context.environment.backgroundLayout)
		}
	}

	/// Removes the background view from the hierarchy and clears its cached transition
	/// when this VC is being dismissed. Safe to call when no background view exists.
	static func completeBackground(
		context: UIPresentation.Context
	) {
		let array = context.viewControllers.toRemove

		if array.contains(context.viewController), let view = context.backgroundView {
			#if VDPRESENT_LOG
			print("  [bg] remove \(context.viewController.view.accessibilityIdentifier ?? "?")")
			#endif
			view.removeFromSuperview()
			context.backgroundTransitions[ObjectIdentifier(view)] = nil
			context.backgroundView = nil
		}
	}
}
