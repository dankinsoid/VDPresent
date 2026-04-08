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
				let identityState = context.environment.identityState(context, context.viewTransitions.state.identity)
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

	var identityState: (UIPresentation.Context, UIViewState) -> UIViewState {
		get { self[\.identityState] ?? { _, identity in identity } }
		set { self[\.identityState] = newValue }
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
	
	// Предполагаю два сценария:
  // все контроллеры под isBehindFrozen анимируются как единое целое - к ним применяется только recess анимация frozen контроллера, при появлении они должны занять финальную позицию еще до начала анимации (за исключением recces анимации frozen) при скрытии - сохранять текущий стейт  (за исключением recces анимации frozen). Если же frozen контроллер не является top то контроллеры за ним вообще не участвуют в анимации - но это регулириуется на стороне UIStackController - он их не добавляет в иерархию. isBehindFrozen анимации в целом никак не отображают изменение стека под top контроллером - просто вставка и удаление top контроллера - вся перестройка стека происходит незаметно от пользователя либо на completion (при insertion) либо в prepare (removal).
	// В целом анимацией контроллеров управляет top - все контроллеры выстраиваются в стопку под его recces анимацию, однако top контроллеров может быть двое - уходящий и приходящий. контроллеры которые уходят анимируются в соответствии с recces анимацией прошлого top контроллера (или лучше кэшировать анимацию с которой они появились и при скрытии использовать ее?); остальные контроллеры анимириуются в соответсвии с recces анимацией нового топ контроллера. Если топ контроллер не менялся - используем его recces для всех.
	// Если один из top контроллеров не уходит/приходит а меняет свою позицию в стеке:
  // - При isBehindFrozen анимируем его как уходящий/приходящий
  // - В других ситуациях вероятно не избежать мелькания и это касается не только топ контроллера - все видимые контроллеры меняют z позицию без анимации - альтернативный вариант делать keyframe анимацию удаления/вставки - нужна поддержка на уровне UIStackController, пока в TODO.

	/// Collects own contentTransition + recess effects from all controllers above
	/// this one, combines them into a single transition, captures identity state,
	/// and applies `progress`.
	@MainActor
	static func buildTransitions(
		context: UIPresentation.Context,
		progress: Progress,
		animation: ((UIPresentation.Context, Progress) -> Void)?
	) {
		var from: [UIViewTransition.TransitionClosure] = []
		var to: [UIViewTransition.TransitionClosure] = []

		// Background transition — built alongside the view using the same conditions.
//		let backgroundView = context.backgroundView
//		let bgTransition = context.environment.backgroundTransition
//		let hasBg = backgroundView != nil && !bgTransition.isIdentity
//		var bgFrom: [UIViewTransition.TransitionClosure] = []
//		var bgTo: [UIViewTransition.TransitionClosure] = []

		// Own contentTransition.
		let contentTransition = context.environment.contentTransition(context)

		if context.isNewView {
			// setup identity state for new view
			context.viewTransitions.state = context.environment.identityState(context, UIViewState())
		}
		var currentState = context.viewTransitions.state
		currentState.snapshot(context.view)

		if context.isBehindFrozen, let top = context.topViewControllers.last {
			// 1 - isBehindFrozen controller
			
			let topContext = context.for(top)
			switch context.direction {
			case .insertion:
				let depth = (context.visibleViewControllers.from.reversed().firstIndex(of: context.viewController) ?? 0) + 1
				let topReccesTransition = topContext.environment.recessTransition(depth, topContext)
				
				if context.isNewView {
					// isBehindFrozen cannot be a new one on insertion - only top controller should be inserted visually
				} else {
					// `from` = current state, identity transform
					// `to` must be computed relativily to `from`
					to.append { [currentState] _, identity in
						identity.merged(with: currentState)
					}
					to.append(topReccesTransition.idle)
				}
			case .removal:
				if !context.isNewView {
					// should never happen but if happen let's reset the view state
					from.append { _, identity in
						context.environment.identityState(context, identity.identity)
					}
				}

				// should start animation from inserted state
				from.append(contentTransition.idle)
				
				if let depth: Int = context.visibleViewControllers.to.reversed().firstIndex(of: context.viewController) {
					
					// should apply recces transition of the new top controller before animation
					if let toTopVC = context.visibleViewControllers.to.last, toTopVC !== context.viewController {
						let toTopContext = context.for(toTopVC)
						let toTopReccesTransition = toTopContext.environment.recessTransition(depth, toTopContext)
						from.append(toTopReccesTransition.idle)
					}
					
					// `to` state is the same as `from` but without departing top reccess transition
					// when top controller is removed it's recces transition doesn't affect any more so no `to` recces state here
					to = from
					
					// should apply recces transition of the departing top controller before animation
					let topReccesTransition = topContext.environment.recessTransition(depth, topContext)
					from.append(topReccesTransition.idle)
				} else {
					// never should happen - a departing frozen controller is not a part of the context
				}
			}
		} else {
			let fromDepth: Int? = context.visibleViewControllers.from.reversed().firstIndex(of: context.viewController)
			let toDepth: Int? = context.visibleViewControllers.to.reversed().firstIndex(of: context.viewController)
			
			
			let fromTopVC = context.visibleViewControllers.from.last
			
			switch (fromDepth, toDepth) {
			case (let .some(fromDepth), .none):
				// 2 departing transition
				let fromTopVC = fromTopVC! // from is not empty when fromDepth is not nil
				
				// TODO: если прошлый top не уходит как должен анимироваться departing контроллера?
				// 1. с recces анимацией прошлого top - как сейчас
				// 2. с recces анимацией нового top
				// 3. с recces анимацией и прошлого и нового top
				
				let fromTopVCContext = context.for(fromTopVC)
				
				let isItTopDeparting = fromTopVC === context.viewController
				let transition = isItTopDeparting
				? contentTransition
				: fromTopVCContext.environment.recessTransition(fromDepth, fromTopVCContext)
				
				if context.isNewView {
					// should never happen for departing non behind frozen
					from.append(transition.idle)
				}
				to.append(transition.didDisappear)
				
			case (_, let .some(toDepth)):
				// 3 remaining or insertion transition
				let toTopVC = context.visibleViewControllers.to.last! // context.visibleViewControllers.to is not empty when toDepth is not nil
				let isItToTop = toTopVC === context.viewController
				
				let toTopVCContext = context.for(toTopVC)
				
				let transition = isItToTop
				? contentTransition
				: toTopVCContext.environment.recessTransition(toDepth, toTopVCContext)
				
				if context.isNewView {
					// insertion
					from.append(transition.willAppear)
				}
				to.append(transition.idle)
				
			case (.none, .none):
				// impossible
				break
			}
		}

		// TODO: return background transition (move to the separate modifier?)
//		let bgTween = hasBg ? bgTransition.tween(for: context.ownDirection) : nil
//
//		if context.isNewView {
//			if context.isChangingController, !context.isBehindFrozen {
//				if let bgTween { bgFrom.append(bgTween.from) }
//			} else {
//				if let bgTween { bgFrom.append(bgTween.to) }
//			}
//		}
//
//		if !context.isBehindFrozen || context.isNewView {
//			if let bgTween { bgTo.append(bgTween.to) }
//		}
//
//		if context.isBehindFrozen {
//			// Freeze existing background — keep it at its current visual state.
//			// New backgrounds have no meaningful state to freeze (just .clear),
//			// so they get bgTween.to instead.
//			if hasBg, let backgroundView {
//				let bgID = ObjectIdentifier(backgroundView)
//				let isExistingBg = context.backgroundTransitions[bgID]?.viewID == bgID
//				if isExistingBg {
//					var bgOld = context.backgroundTransitions[bgID]!.state
//					bgOld.snapshot(backgroundView)
//					bgTo.insert(
//						{ [bgOld] _, identity in
//							identity.merged(with: bgOld)
//						},
//						at: 0
//					)
//				} else if let bgTween {
//					bgTo.append(bgTween.to)
//				}
//			}
//		}

		let newTransition = UIViewTransition.Tween.combined(from: from, to: to)
		let newState = newTransition.from(context.view, currentState)

		newState.apply(to: context.view)

		context.viewTransitions.tween = newTransition
		context.viewTransitions.oldState = currentState
		context.viewTransitions.state = newState
		context.viewTransitions.progress = progress
		context.viewTransitions.viewID = ObjectIdentifier(context.view)

//		// Apply background transition.
//		if hasBg, let backgroundView {
//			let bgID = ObjectIdentifier(backgroundView)
//			var bgTransitions = context.backgroundTransitions[bgID] ?? ViewTransitions()
//
//			var bgOldState = bgTransitions.state
//			bgOldState.snapshot(backgroundView)
//
//			let bgCombined = UIViewTransition.Tween.combined(from: bgFrom, to: bgTo)
//			let bgNewState = bgCombined.from(backgroundView, bgOldState)
//			bgNewState.apply(to: backgroundView)
//
//			bgTransitions.tween = bgCombined
//			bgTransitions.oldState = bgOldState
//			bgTransitions.state = bgNewState
//			bgTransitions.progress = progress
//			bgTransitions.viewID = ObjectIdentifier(backgroundView)
//			context.backgroundTransitions[bgID] = bgTransitions
//		}

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
		if !completed {
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
		guard !transition.isIdentity, context.backgroundView == nil else { return }
		let backgroundView = UIView()
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

	/// Removes the background view from the hierarchy and clears its cached transition
	/// when this VC is being dismissed. Safe to call when no background view exists.
	static func completeBackground(
		context: UIPresentation.Context
	) {
		let array = context.viewControllers.toRemove

		if array.contains(context.viewController), let view = context.backgroundView {
			view.removeFromSuperview()
			context.backgroundTransitions[ObjectIdentifier(view)] = nil
			context.backgroundView = nil
		}
	}
}
