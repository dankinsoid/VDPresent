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
				#if VDPRESENT_LOG
				if let existingAnimator {
					print("[Animator] REUSING existing animator state=\(existingAnimator.state) running=\(existingAnimator.isRunning)")
				}
				print("[Animator] created duration=\(animator.duration) mainContextDuration=\(main.context.animation.duration)")
				#endif
				main.context.animator = animator
				// Allow touches during interactive transitions so the UI stays
				// responsive while the animator runs (especially the reverse
				// animation after a cancelled gesture).
				animator.isUserInteractionEnabled = true
				#if VDPRESENT_LOG
				print("[Animator] addAnimations REGISTERING items=\(items.count) animatorState=\(animator.state)")
				#endif
				animator.addAnimations {
					#if VDPRESENT_LOG
					print("[Animator] addAnimations EXECUTING items=\(items.count) state=\(animator.state) running=\(animator.isRunning)")
					for (context, _) in items {
						let v = context.view
						print("[Animator]   view=\(v.accessibilityIdentifier ?? String(describing: type(of: v))) t=\(v.transform) alpha=\(v.alpha) superview=\(v.superview != nil) window=\(v.window != nil)")
					}
					#endif
					animate()
					#if VDPRESENT_LOG
					for (context, _) in items {
						let v = context.view
						print("[Animator]   AFTER view=\(v.accessibilityIdentifier ?? String(describing: type(of: v))) t=\(v.transform) alpha=\(v.alpha)")
					}
					#endif
				}
				#if VDPRESENT_LOG
				let animatorId = ObjectIdentifier(animator)
				print("[Animator] setup id=\(animatorId) state=\(animator.state)")
				#endif
				animator.addCompletion { position in
					let completed = position == .end
					#if VDPRESENT_LOG
					print("[Animator] completion id=\(animatorId) position=\(position == .end ? "end" : position == .start ? "start" : "current") completed=\(completed)")
					#endif
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
							#if VDPRESENT_LOG
							print("[Animator] pre-start state=\(animator.state) running=\(animator.isRunning) inheritedDuration=\(UIView.inheritedAnimationDuration) runLoopMode=\(RunLoop.current.currentMode?.rawValue ?? "nil") areAnimationsEnabled=\(UIView.areAnimationsEnabled)")
							for (context, _) in items {
								let v = context.view
								let pres = v.layer.presentation()
								let hasAnim = v.layer.animationKeys()?.isEmpty == false
								print("[Animator]   pre-start view model.t=\(v.transform) pres.t=\(pres?.affineTransform() as Any) hasLayerAnims=\(hasAnim)")
							}
							#endif
							animator.startAnimation()
							#if VDPRESENT_LOG
							print("[Animator] post-start state=\(animator.state) running=\(animator.isRunning) fraction=\(String(format: "%.3f", animator.fractionComplete)) hasLayerAnims=\(items.first.map { $0.context.view.layer.animationKeys()?.isEmpty == false } ?? false)")
							#endif
							animator.pauseAnimation()
							#if VDPRESENT_LOG
							print("[Animator] post-pause state=\(animator.state) running=\(animator.isRunning) fraction=\(String(format: "%.3f", animator.fractionComplete))")
							#endif
						}

					case let .change(progress):
						if animator.fractionComplete != progress.value {
							animator.fractionComplete = progress.value
						}

					case let .end(completed, duration):
						if !main.context.animatorDidContinue {
							main.context.animatorDidContinue = true
							#if VDPRESENT_LOG
							print("[Animator] continue completed=\(completed) duration=\(String(format: "%.3f", duration)) state=\(animator.state) fraction=\(String(format: "%.3f", animator.fractionComplete))")
							#endif
							animator.isReversed = !completed
							animator.continueAnimation(duration: duration)
							#if VDPRESENT_LOG
							print("[Animator] after continue state=\(animator.state) running=\(animator.isRunning)")
							AnimatorFrameLogger.start(animator: animator, ctxAlive: { main.context.animator != nil })
							#endif
						} else {
							#if VDPRESENT_LOG
							print("[Animator] .end ignored — animatorDidContinue already true")
							#endif
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

#if VDPRESENT_LOG
private class AnimatorFrameLogger: NSObject {
	private weak var animator: UIViewPropertyAnimator?
	private var ctxAlive: () -> Bool
	private var frameCount = 0
	private var link: CADisplayLink?

	static func start(animator: UIViewPropertyAnimator, ctxAlive: @escaping () -> Bool) {
		let logger = AnimatorFrameLogger(animator: animator, ctxAlive: ctxAlive)
		logger.link = CADisplayLink(target: logger, selector: #selector(tick))
		logger.link?.add(to: .main, forMode: .common)
	}

	private init(animator: UIViewPropertyAnimator, ctxAlive: @escaping () -> Bool) {
		self.animator = animator
		self.ctxAlive = ctxAlive
	}

	@objc private func tick() {
		frameCount += 1
		guard let animator else {
			print("[Animator] frame#\(frameCount) animator deallocated")
			link?.invalidate()
			return
		}
		let s = animator.state
		let r = animator.isRunning
		let f = animator.fractionComplete
		print("[Animator] frame#\(frameCount) state=\(s) running=\(r) fraction=\(String(format: "%.3f", f)) ctxAnimator=\(ctxAlive() ? "alive" : "nil")")
		if s == .inactive || frameCount > 180 {
			link?.invalidate()
			print("[Animator] displayLink stopped")
		}
	}
}
#endif
