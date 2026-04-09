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
				: .tween(\.backgroundColor, from: color.withAlphaComponent(0), to: color),
			layout: layout
		)
	}
	
	func withBackground() -> UIPresentation.Transition {
		UIPresentation.Transition(
			transitionID: transitionID,
			environment: environment
		) { ctx in
			Self.prepareBackground(context: ctx)
			prepare(ctx)
		} animation: { ctx in
			Self.animateBackground(context: ctx)
			animation(ctx)
		} completion: { ctx, completed in
			Self.completeBackground(context: ctx, completed: completed)
			completion(ctx, completed)
		}
	}

	func withBackground(
		_ transition: UIViewTransition,
		layout: ContentLayout = .fill
	) -> UIPresentation.Transition {
		withBackground()
			.environment(\.backgroundTransition, transition)
			.environment(\.backgroundLayout, layout)
			.environment(\.backgroundPlacement, .global)
	}

	func withOverlay(
		_ color: UIColor
	) -> UIPresentation.Transition {
		withBackground(color).environment(\.backgroundPlacement, .behindController)
	}
	
	func withOverlay(
		_ transition: UIViewTransition
	) -> UIPresentation.Transition {
		withBackground(transition).environment(\.backgroundPlacement, .behindController)
	}
}

public extension UIPresentation.Environment {

	var backgroundLayout: ContentLayout {
		get { self[\.backgroundLayout] ?? .fill }
		set { self[\.backgroundLayout] = newValue }
	}

	var backgroundTransition: UIViewTransition {
		get { self[\.backgroundTransition] ?? .identity }
		set { self[\.backgroundTransition] = newValue }
	}
}

/// Where the background/overlay view is placed in the view hierarchy.
public enum BackgroundPlacement {

	/// Background is added to this controller's own canvas (covers the full screen).
	case global

	/// Background is added as a subview of the controller directly behind this one.
	case behindController
}


private extension UIPresentation.Transition {
	

	// MARK: - Debug helpers
	@MainActor
	static func prepareBackground(
		context: UIPresentation.Context
	) {
		let transition = context.environment.backgroundTransition
		guard !transition.isIdentity, context.backgroundView == nil else { return }
		installBackground(context: context, transition: transition)

		guard let backgroundView = context.backgroundView else { return }
		let id = ObjectIdentifier(backgroundView)
		let currentState = context.backgroundStates[id] ?? UIViewState()
		
		let newState: UIViewState
		if context.isBehindFrozen || context.isRemainingController {
			newState = transition.idle(backgroundView, currentState.identity)
		} else {
			let tween = transition.tween(for: context.ownDirection)
			newState = tween.from(backgroundView, currentState)
		}
		newState.apply(to: backgroundView)
		context.backgroundStates[id] = newState
	}
	
	@MainActor
	static func animateBackground(
		context: UIPresentation.Context
	) {
		guard !context.isBehindFrozen, context.isChangingController else { return }
		let transition = context.environment.backgroundTransition

		guard let backgroundView = context.backgroundView else { return }
		let id = ObjectIdentifier(backgroundView)
		let currentState = context.backgroundStates[id] ?? UIViewState()

		let tween = transition.tween(for: context.ownDirection)
		let newState = tween.to(backgroundView, currentState.identity)
		newState.apply(to: backgroundView)
		context.backgroundStates[id] = newState
	}

	/// Ensures the background view exists in the hierarchy. Does not build transitions —
	/// that is handled by `buildTransitions` using the same logic as the main view.
	/// No-ops when `backgroundTransition` is `.identity`.
	@MainActor
	static func installBackground(
		context: UIPresentation.Context,
		transition: UIViewTransition
	) {
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

	/// Settles the background view after animation ends.
	/// - completed: removes background for departing controllers.
	/// - cancelled: restores background to its pre-animation state (e.g. idle opacity),
	///   mirroring how `settleViewState` restores the main view on cancel.
	@MainActor
	static func completeBackground(
		context: UIPresentation.Context,
		completed: Bool
	) {
		guard let backgroundView = context.backgroundView else { return }
		let id = ObjectIdentifier(backgroundView)

		if completed {
			let array = context.viewControllers.toRemove
			if array.contains(context.viewController) {
				backgroundView.removeFromSuperview()
				context.backgroundStates[id] = nil
				context.backgroundView = nil
			}
		} else {
			// Cancel: restore background to idle state (visible).
			// animateBackground moved it to the removal end-state (transparent),
			// but the dismiss was cancelled so it needs to come back.
			let transition = context.environment.backgroundTransition
			guard !transition.isIdentity else { return }
			let currentState = context.backgroundStates[id] ?? UIViewState()
			let idleState = transition.idle(backgroundView, currentState.identity)
			idleState.apply(to: backgroundView)
			context.backgroundStates[id] = idleState
		}
	}
}

extension UIPresentation.Environment {

	var backgroundPlacement: BackgroundPlacement {
		get { self[\.backgroundPlacement] ?? .global }
		set { self[\.backgroundPlacement] = newValue }
	}
}

extension UIPresentation.Context {

	var backgroundStates: [ObjectIdentifier: UIViewState] {
		get {
			cache[\.backgroundStates] ?? [:]
		}
		nonmutating set {
			cache[\.backgroundStates] = newValue
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
