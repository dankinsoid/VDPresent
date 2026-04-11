import UIKit
import VDTransition

/// A container view controller that manages a stack of child view controllers
/// with fully customizable animated and interactive transitions.
///
/// `UIStackController` is the backbone of the VDPresent navigation model. It owns
/// an ordered array of child controllers (`viewControllers`) and drives animated
/// transitions between states via `UIPresentation` descriptors. Each push/pop
/// is modelled as replacing the current stack with a new one, so arbitrary
/// inserts, removals, and reorders are all first-class operations.
///
/// ## Basic usage — direct API
///
/// ```swift
/// let stack = UIStackController()
/// window.rootViewController = stack
///
/// // Push
/// stack.push(HomeViewController())
///
/// // Push with a custom presentation
/// stack.push(DetailViewController(), as: .sheet)
///
/// // Pop one level
/// stack.pop()
///
/// // Pop several levels at once
/// stack.pop(2)
///
/// // Pop to root
/// stack.pop(-1)
///
/// // Replace the entire stack
/// stack.set(viewControllers: [RootViewController(), ListViewController()])
/// ```
///
/// ## Global API — `UIViewController` extensions
///
/// Alongside explicit stack management, VDPresent provides a global
/// `show()`/`hide()` API on `UIViewController` for screens that are not
/// permanently embedded in a navigation hierarchy — alerts, toasts, contextual
/// overlays, or any screen that needs to be reachable from anywhere without a
/// reference to a specific stack.
///
/// These extensions automatically locate the nearest suitable
/// `UIStackController` (or create a temporary one) so the caller doesn't need
/// to know where in the hierarchy it lives:
///
/// ```swift
/// // Show from anywhere — VDPresent resolves the right stack automatically.
/// myViewController.show()
/// myViewController.show(as: .pageSheet)
/// myViewController.show(as: .navigation, animated: true) {
///     print("presented")
/// }
///
/// // Hide (pop) the receiver from its stack, wherever it is.
/// myViewController.hide()
///
/// // Toggle visibility via the `isShown` property.
/// myViewController.isShown = true   // calls show() if not already visible
/// myViewController.isShown = false  // calls hide() if currently visible
///
/// // Set a per-controller default so show() always uses it without arguments.
/// myViewController.defaultPresentation = .navigation
/// myViewController.show()           // uses .navigation automatically
/// ```
///
/// ## Finding the stack from within a child
///
/// ```swift
/// // Walk up the parent chain to the owning UIStackController.
/// viewController.stackController        // nearest ancestor stack, or nil
/// UIStackController.root                // first stack reachable from the key window
/// UIStackController.top                 // deepest (frontmost) stack
/// ```
///
/// ## Interactive transitions
///
/// Assign a `UIPresentation` with an `interactivity` descriptor to get gesture-
/// driven transitions for free:
///
/// ```swift
/// stack.push(DetailViewController(), as: .sheet)
/// // The sheet presentation ships with an edge-pan recogniser out of the box.
/// ```
///
/// ## Subclassing
///
/// Override `wrap(view:)` to customise how child views are embedded before
/// transitions animate them (e.g. to add drop-shadows or rounded corners at
/// the wrapper level rather than in each child).
open class UIStackController: UIViewController {

	public private(set) var viewControllers: [UIViewController] = []
	public private(set) var isSettingControllers = false
	public var presentation: UIPresentation?

	override public var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
	override open var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { statusBarAnimation }
	override open var preferredStatusBarStyle: UIStatusBarStyle { statusBarStyle }

	private let content = UIStackControllerView()
	private var containers: [UUID: UIStackControllerCanvas] = [:]
	private var wrappers: [UUID: UIStackEffectView] = [:]
	private var presentations: [UUID: UIPresentation] = [:]
	/// Single callback for the current interactive transition.
	/// Replaces per-VC dictionary to avoid stale callbacks from previous transitions.
	private var activeTransitionUpdate: ((UIPresentation.Interactivity.State) -> Void)?
	private let cache = UIPresentation.Context.Cache()
	private var queue: [Setting] = []
	private var statusBarAnimation: UIStatusBarAnimation = .fade
	private var statusBarStyle: UIStatusBarStyle = .default {
		didSet {
			guard oldValue != statusBarStyle else { return }
			setNeedsStatusBarAppearanceUpdate()
		}
	}

	override public func loadView() {
		view = content
	}

	override open func viewDidLoad() {
		super.viewDidLoad()
		modalPresentationStyle = .overFullScreen
		view.backgroundColor = .clear
	}

	override open func show(_ vc: UIViewController, sender: Any?) {
		push(vc)
	}

	override open func showDetailViewController(_ vc: UIViewController, sender: Any?) {
		push(vc)
	}

	override open func targetViewController(forAction action: Selector, sender: Any?) -> UIViewController? {
		super.targetViewController(forAction: action, sender: sender)
	}

	@available(iOS 15.0, *)
	override open func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
		topViewController?.contentScrollView(for: edge)
	}

	open func set(
		viewControllers newViewControllers: [UIViewController],
		as presentation: UIPresentation? = nil,
		direction: TransitionDirection? = nil,
		animated: Bool = true,
		completion: (@MainActor () -> Void)? = nil
	) {
		guard !isSettingControllers else {
			queue.append(
				Setting(
					viewControllers: newViewControllers,
					presentation: presentation,
					direction: direction,
					animated: animated,
					completion: completion
				)
			)
			return
		}

		guard newViewControllers != viewControllers else {
			completion?()
			return
		}

		let isEmpty = newViewControllers.isEmpty
		if isEmpty, self === UIWindow.root?.rootViewController {
			completion?()
			return
		}

		let isInsertion = newViewControllers.last.map { !viewControllers.contains($0) } ?? false

		let prsnt = presentation ?? self.presentation(for: isInsertion ? newViewControllers : viewControllers)

		transition(
			direction: direction ?? (isInsertion ? .insertion : .removal),
			to: newViewControllers,
			from: viewControllers,
			presentation: prsnt,
			animated: animated,
			isInteractive: false,
			completion: completion
		)
	}

	open func wrap(view: UIView) -> UIStackEffectView {
		UIStackEffectView(view)
	}
}

private extension UIStackController {

	/// Resolves the effective presentation for a single controller.
	/// Chain: stored → defaultPresentation → fallback.
	func resolvePresentation(
		for vc: UIViewController,
		fallback: UIPresentation
	) -> UIPresentation {
		presentations[vc.vdStableID] ?? vc.defaultPresentation ?? fallback
	}

	func presentation(
		for viewControllers: [UIViewController]
	) -> UIPresentation {
		if UIWindow.root?.rootViewController === self, viewControllers.count < 2 {
			return .fullScreen(from: .bottom, containerColor: .clear)
		}
		return viewControllers.last.flatMap { presentations[$0.vdStableID] ?? $0.defaultPresentation } ?? presentation ?? .default
	}
}

private extension UIStackController {

	/// @ai-generated(paired)
	func transition(
		direction: TransitionDirection,
		to toViewControllers: [UIViewController],
		from fromViewControllers: [UIViewController],
		presentation: UIPresentation,
		animated: Bool,
		isInteractive: Bool,
		completion: (() -> Void)?
	) {
		let controllers = UIPresentation.Context.Controllers(
			fromViewControllers: fromViewControllers,
			toViewControllers: toViewControllers
		)

		let resolve: (UIViewController) -> UIPresentation = { [presentations] in
			presentations[$0.vdStableID] ?? $0.defaultPresentation ?? presentation
		}
		let visibleControllers = controllers.visible(resolve)

		let context: (UIViewController) -> UIPresentation.Context = { [weak self, cache] in
			let resolved = self?.resolvePresentation(for: $0, fallback: presentation) ?? presentation
			return UIPresentation.Context(
				direction: direction,
				controller: $0,
				container: { [weak self] in self?.container(for: $0) ?? UIStackControllerCanvas() },
				fromViewControllers: fromViewControllers,
				toViewControllers: toViewControllers,
				views: { [weak self] in self?.wrapper(for: $0) ?? UIStackEffectView($0.view) },
				animated: animated,
				animation: resolved.animation,
				isInteractive: isInteractive,
				cache: cache,
				updateStatusBar: { [weak self] in
					self?.statusBarAnimation = $1
					self?.statusBarStyle = $0
				},
				presentation: { [weak self] in self?.resolvePresentation(for: $0, fallback: presentation) ?? presentation }
			)
		}
		transition(
			presentation: presentation,
			direction: direction,
			animated: animated,
			controllers: controllers,
			visibleControllers: visibleControllers,
			context: context,
			completion: completion
		)
	}

	/// `controllers` — full stack for structural ops (addChild, removeFromParent).
	/// `visibleControllers` — visible slice for animation pipeline.
	/// @ai-generated(paired)
	func transition(
		presentation: UIPresentation,
		direction: TransitionDirection,
		animated: Bool,
		controllers: UIPresentation.Context.Controllers,
		visibleControllers: UIPresentation.Context.Controllers,
		context: @escaping (UIViewController) -> UIPresentation.Context,
		completion: (() -> Void)?
	) {
		isSettingControllers = true
		viewControllers = controllers.to

		// Ensure all visible `to` controllers have wrappers/containers.
		// Controllers re-entering the visible zone (after their container was
		// removed while off-screen) need these recreated, not just toInsert.
		var reenteredVisible: [UIViewController] = []
		for toViewController in visibleControllers.to {
			let vcID = toViewController.vdStableID
			let needsSetup = wrappers[vcID] == nil
			if needsSetup {
				wrappers[vcID] = wrap(view: toViewController.view)
			}
			if containers[vcID] == nil {
				container(for: toViewController)
			}
			if presentations[vcID] == nil {
				presentations[vcID] = toViewController.defaultPresentation ?? presentation
			}
			if needsSetup, !visibleControllers.toInsert.contains(toViewController) {
				reenteredVisible.append(toViewController)
			}
		}
		// Add views for new visible controllers (toInsert + re-entered).
		for toViewController in visibleControllers.toInsert + reenteredVisible {
			let ctx = context(toViewController)
			ctx.container.addSubview(ctx.view, layout: ctx.environment.contentLayout)
		}

		// Iterate only visible controllers for z-ordering and animation.
		let allVisible = visibleControllers.all(direction)
		allVisible.map(container).forEach(content.bringSubviewToFront)

		// Force layout of the freshly added wrappers/containers so that the
		// prepare phase below sees valid `bounds` when computing the initial
		// offscreen state.
		content.layoutIfNeeded()

		// Structural: addChild for ALL new controllers.
		for toViewController in controllers.to where toViewController.parent == nil {
			toViewController.willMove(toParent: self)
			self.addChild(toViewController)
			toViewController.didMove(toParent: self)
		}

		for vc in visibleControllers.toInsert where vc !== visibleControllers.to.last {
			vc.unlockSafeAreaPropagation()
		}

		for item in controllers.toRemove {
			item.willMove(toParent: nil)
		}

		// Store visible slice in shared cache so applyBackEffects iterates
		// only visible controllers (skipping barriers from non-visible departing VCs).
		if let first = allVisible.first {
			context(first).visibleViewControllers = visibleControllers
		}

		// Animation pipeline: only visible controllers.
		for controller in allVisible {
			let currentPresentation = resolvePresentation(for: controller, fallback: presentation)
			AnimationDriver.prepare(
				transition: currentPresentation.transition,
				context: context(controller)
			)
		}

		#if VDPRESENT_LOG
		logTransitionState("prepare", allVisible: allVisible, controllers: controllers, context: context)
		#endif

		// Reversed so top views update first — recessTransitions that
		// read target view frames see the correct animate-phase position.
		AnimationDriver.animate(
			allVisible.reversed().map { vc in
				(context(vc), resolvePresentation(for: vc, fallback: presentation).transition)
			},
			beginAppearance: {
				if !controllers.isTopTheSame {
					if let vc = controllers.to.last {
						vc.beginAppearanceTransition(true, animated: animated)
					}
					if let vc = controllers.from.last {
						vc.beginAppearanceTransition(false, animated: animated)
					}
				}
			},
			prepareInteractive: { [weak self] update in
				self?.activeTransitionUpdate = update
			},
			completion: { [weak self] completed in
				#if VDPRESENT_LOG
				logTransitionState("animate", allVisible: allVisible, controllers: controllers, context: context)
				#endif
				self?.activeTransitionUpdate = nil
				self?.completionBlock(
					presentation: presentation,
					direction: direction,
					controllers: controllers,
					visibleControllers: visibleControllers,
					context: context,
					isCompleted: completed,
					completion: completion
				)
			}
		)
	}

	/// Runs after the animation pipeline resolves.
	///
	/// The transition can either **complete** (the new stack wins) or be
	/// **cancelled** (roll back to the previous stack). Both branches share
	/// the same cleanup shape, parameterised by what the "surviving" slice
	/// is:
	///
	/// - Completed → survivors are `controllers.to` / `visibleControllers.to`.
	/// - Cancelled → survivors are `controllers.from` / `visibleControllers.from`.
	///
	/// Cleanup rules applied to every controller touched by this transition:
	/// 1. Not in the final stack → structurally removed (`removeFromParent`),
	///    wrapper/container/presentation dropped, and its per-view transition
	///    cache entry cleared so a later re-presentation is treated as a
	///    fresh view (`isNewView == true`) and gets its initial offscreen
	///    state applied before animating.
	/// 2. In the final stack but not in the final visible slice → wrapper
	///    and container are evicted so off-screen controllers don't retain
	///    view hierarchy resources, while the presentation entry is kept.
	/// 3. In the final visible slice → fully preserved.
	/// @ai-generated(paired)
	func completionBlock(
		presentation: UIPresentation,
		direction: TransitionDirection,
		controllers: UIPresentation.Context.Controllers,
		visibleControllers: UIPresentation.Context.Controllers,
		context: @escaping (UIViewController) -> UIPresentation.Context,
		isCompleted: Bool,
		completion: (() -> Void)?
	) {
		// Let each visible transition finalise its own state before we
		// start dismantling the view hierarchy it may still reference.
		for controller in visibleControllers.all(direction) {
			resolvePresentation(for: controller, fallback: presentation)
				.transition.completion(context(controller), isCompleted)
		}

		let finalControllers = isCompleted ? controllers.to : controllers.from
		let finalVisible = isCompleted ? visibleControllers.to : visibleControllers.from
		viewControllers = finalControllers

		// End appearance transitions before the losing top's wrapper is
		// torn down — UIKit expects the view to still be in the hierarchy
		// when `endAppearanceTransition` fires.
		if !controllers.isTopTheSame {
			controllers.to.last?.endAppearanceTransition()
			controllers.from.last?.endAppearanceTransition()
		}

		// Install/uninstall interactive gestures before caches are pruned
		// so that uninstall can still resolve each controller's presentation
		// and install sees the current wrappers/containers.
		if isCompleted {
			configureInteractivity(
				presentation: presentation,
				controllers: controllers,
				context: context
			)
		} else {
			statusBarStyle = controllers.from.last?.preferredStatusBarStyle ?? statusBarStyle
		}

		// Structurally remove controllers the resolved stack discards:
		// `toRemove` on completion (genuinely removed), `toInsert` on
		// cancel (insertions that never took effect).
		let structurallyRemoved = isCompleted ? controllers.toRemove : controllers.toInsert
		for vc in structurallyRemoved {
			if !isCompleted {
				vc.willMove(toParent: nil)
			}
			vc.removeFromParent()
			vc.didMove(toParent: nil)
		}

		// Per-controller cache eviction, driven by the final visible slice.
		// Candidates are controllers this transition actually touched —
		// anything else in the stack is left alone.
		let finalVisibleIDs = Set(finalVisible.map(\.vdStableID))
		let finalStackIDs = Set(finalControllers.map(\.vdStableID))
		var seen: Set<UUID> = []
		for vc in visibleControllers.to + visibleControllers.from + structurallyRemoved {
			let id = vc.vdStableID
			guard seen.insert(id).inserted else { continue }
			guard !finalVisibleIDs.contains(id) else { continue }
			wrappers[id]?.removeFromSuperview()
			wrappers[id] = nil
			containers[id]?.removeFromSuperview()
			containers[id] = nil
			if !finalStackIDs.contains(id) {
				presentations[id] = nil
				// Drop the per-view transition state so that a later
				// re-presentation is treated as a fresh view and receives
				// its initial offscreen state before animating.
				if var transitions = cache[\.allViewTransitions] {
					transitions[id] = nil
					cache[\.allViewTransitions] = transitions
				}
			}
		}

		didSetViewControllers()
		isSettingControllers = false
		completion?()
		if let next = queue.first {
			queue.removeFirst()
			set(
				viewControllers: next.viewControllers,
				as: next.presentation,
				direction: next.direction,
				animated: next.animated,
				completion: next.completion
			)
		}
	}

	func configureInteractivity(
		presentation: UIPresentation,
		controllers: UIPresentation.Context.Controllers,
		context: @escaping (UIViewController) -> UIPresentation.Context
	) {
		for item in controllers.toRemove {
			resolvePresentation(for: item, fallback: presentation)
				.interactivity?.uninstall(context: context(item))
		}
		// Install for all `to` controllers, not just toInsert.
		// Controllers re-entering the visible zone get new containers,
		// so their gesture recognizers must be reinstalled.
		for controller in controllers.to {
			let ctxt = context(controller)
			let prsnt = resolvePresentation(for: controller, fallback: presentation)
			prsnt.interactivity?.install(context: ctxt) { [weak self] context, state in
				guard let self else { return .prevent }
				switch state {
				case .begin:
					guard !self.isSettingControllers else { return .prevent }
					let controllers = context.viewControllers
					let resolve: (UIViewController) -> UIPresentation = {
						self.resolvePresentation(for: $0, fallback: presentation)
					}
					// Compute visible slice same as non-interactive path,
					// so controllers behind an opaque one are excluded.
					let visibleControllers = controllers.visible(resolve)
					self.transition(
						presentation: presentation,
						direction: context.direction,
						animated: context.animated,
						controllers: controllers,
						visibleControllers: visibleControllers,
						context: context.for,
						completion: nil
					)

				default:
					break
				}
				self.activeTransitionUpdate?(state)
				return .allow
			}
		}
	}
}

private extension UIStackController {

	func didSetViewControllers() {
		let idSet = Set(viewControllers.map(\.vdStableID))
		containers = containers.filter { idSet.contains($0.key) }
		wrappers = wrappers.filter { idSet.contains($0.key) }
		presentations = presentations.filter { idSet.contains($0.key) }
		updateContainers()
	}

	func wrapper(for controller: UIViewController) -> UIStackEffectView {
		wrappers[controller.vdStableID] ?? UIStackEffectView(controller.view)
	}

	@discardableResult
	func container(for controller: UIViewController) -> UIStackControllerCanvas {
		let id = controller.vdStableID
		if let result = containers[id] {
			return result
		}
		let container = UIStackControllerCanvas()
		container.backgroundColor = .clear
		containers[id] = container
		content.containers.append(container)
		return container
	}

	func updateContainers() {
		// Only include containers that already exist — non-visible controllers
		// may have had their containers intentionally removed.
		content.containers = viewControllers.compactMap { containers[$0.vdStableID] }
	}
}

private extension UIStackController {

	struct Setting {

		var viewControllers: [UIViewController]
		var presentation: UIPresentation?
		var direction: TransitionDirection?
		var animated: Bool
		var completion: (() -> Void)?
	}
}
