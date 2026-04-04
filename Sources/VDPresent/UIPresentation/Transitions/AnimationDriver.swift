import UIKit

/// Runs `UIPresentation.Transition` callbacks using `UIView.animate` or
/// `UIViewPropertyAnimator` (for interactive transitions).
///
/// `AnimationDriver` owns the *how* of animating — the `Transition` owns the *what*.
/// This separation lets the same transition description be driven by different
/// mechanisms (standard animation, interactive gesture, instant snap) without
/// changing the transition itself.
/// @ai-generated(guided)
enum AnimationDriver {

	/// Runs the prepare phase: adds the view to the container if needed,
	/// then calls `transition.prepare`.
	///
	/// Must be called for all controllers before calling `animate`,
	/// so that cross-controller state (e.g. back-view transforms) is
	/// fully set up before any animation begins.
	@MainActor
	static func prepare(
		transition: UIPresentation.Transition,
		context: UIPresentation.Context
	) {
		if !context.viewControllers.from.contains(context.viewController) {
			context.container
				.addSubview(
					context.view,
					layout: context.environment.contentLayout
				)
		}
		transition.prepare(context)
	}

	/// Runs the animate + completion phases using `UIView.animate`,
	/// `UIViewPropertyAnimator` (interactive), or instant snap (non-animated).
	///
	/// - Parameters:
	///   - transition: The transition describing visual changes.
	///   - context: The presentation context for the target view controller.
	///   - beginAppearance: Called at the start of the animation block (before visual changes).
	///   - prepareInteractive: Called when an interactive animator is created; provides
	///     a handler that the gesture recognizer should call with state updates.
	///   - completion: Called after the animation finishes.
	@MainActor
	static func animate(
		_ items: [(context: UIPresentation.Context, transition: UIPresentation.Transition)],
		beginAppearance: @escaping @MainActor () -> Void = {},
		prepareInteractive: @escaping @MainActor (@escaping (UIPresentation.Interactivity.State) -> Void) -> Void = { _ in },
		completion: @escaping @MainActor (Bool) -> Void
	) {

		let main = items.max(by: { $0.context.animation.duration < $1.context.animation.duration })
		guard let main else {
			completion(true)
			return
		}
		let animate: @MainActor () -> Void = {
			beginAppearance()
			for (context, transition) in items {
				transition.animation(context)
			}
		}
		let complete: (Bool) -> Void = { completed in
			completion(completed)
		}

		if main.context.animated {
			if main.context.isInteractive {
				let existingAnimator = main.context.animator
				let animator = existingAnimator ?? Animator(duration: main.context.animation.duration, curve: .linear)
				main.context.animator = animator
				// Allow touches during interactive transitions so the UI stays
				// responsive while the animator runs (especially the reverse
				// animation after a cancelled gesture).
				animator.isUserInteractionEnabled = true
				animator.addAnimations {
					animate()
				}
				animator.addCompletion { position in
					let completed = position == .end
					complete(completed)
					main.context.animator?.finishAnimation(at: completed ? .end : .start)
					main.context.animator = nil
					main.context.animatorDidContinue = false
					main.context.animatorDidStart = false
				}
				prepareInteractive { state in
					switch state {
					case .begin:
						if !main.context.animatorDidStart {
							main.context.animatorDidStart = true
							animator.startAnimation()
							animator.pauseAnimation()
						}

					case let .change(progress):
						if animator.fractionComplete != progress.value {
							animator.fractionComplete = progress.value
						}

					case let .end(completed, duration):
						if !main.context.animatorDidContinue {
							main.context.animatorDidContinue = true
							animator.isReversed = !completed
							animator.continueAnimation(duration: duration)
						}
					}
				}
			} else {
				UIView.animate(with: main.context.animation, animate, completion: complete)
			}
		} else {
			animate()
			complete(true)
		}
	}
}

// MARK: - Context cache for interactive animator state

extension UIPresentation.Context {

	var animator: Animator? {
		get { cache[\.animator] ?? nil }
		nonmutating set { cache[\.animator] = newValue }
	}

	var animatorDidContinue: Bool {
		get { cache[\.animatorDidContinue] ?? false }
		nonmutating set { cache[\.animatorDidContinue] = newValue }
	}

	var animatorDidStart: Bool {
		get { cache[\.animatorDidStart] ?? false }
		nonmutating set { cache[\.animatorDidStart] = newValue }
	}
}
