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
	private var containers: [UIViewController: UIStackControllerCanvas] = [:]
	private var wrappers: [UIViewController: UIStackEffectView] = [:]
	private var presentations: [UIViewController: UIPresentation] = [:]
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

	func presentation(
		for viewControllers: [UIViewController]
	) -> UIPresentation {
		if UIWindow.root?.rootViewController === self, viewControllers.count < 2 {
			return .fullScreen(from: .bottom, containerColor: .clear)
		}
		return viewControllers.last.flatMap { presentations[$0] ?? $0.defaultPresentation } ?? presentation ?? .default
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

		let presentations = self.presentations
		let resolve: (UIViewController) -> UIPresentation = {
			presentations[$0] ?? $0.defaultPresentation ?? presentation
		}
		let visibleControllers = controllers.visible(resolve)

		let context: (UIViewController) -> UIPresentation.Context = { [weak self, cache] in
			let presentations = self?.presentations ?? [:]
			return UIPresentation.Context(
				direction: direction,
				controller: $0,
				container: { [weak self] in self?.container(for: $0) ?? UIStackControllerCanvas() },
				fromViewControllers: fromViewControllers,
				toViewControllers: toViewControllers,
				views: { [weak self] in self?.wrapper(for: $0) ?? UIStackEffectView($0.view) },
				animated: animated,
				animation: (presentations[$0] ?? presentation).animation,
				isInteractive: isInteractive,
				cache: cache,
				updateStatusBar: { [weak self] in
					self?.statusBarAnimation = $1
					self?.statusBarStyle = $0
				},
				presentation: { presentations[$0] ?? presentation }
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
		#if VDPRESENT_LOG
		print("[Transition] begin isSettingControllers=\(isSettingControllers) isInteractive=\(controllers.to.first.map { context($0).isInteractive } ?? false) hasActiveTransition=\(activeTransitionUpdate != nil)")
		#endif
		isSettingControllers = true
		viewControllers = controllers.to

		// Ensure all visible `to` controllers have wrappers/containers.
		// Controllers re-entering the visible zone (after their container was
		// removed while off-screen) need these recreated, not just toInsert.
		var reenteredVisible: [UIViewController] = []
		for toViewController in visibleControllers.to {
			let needsSetup = wrappers[toViewController] == nil
			if needsSetup {
				wrappers[toViewController] = wrap(view: toViewController.view)
			}
			if containers[toViewController] == nil {
				container(for: toViewController)
			}
			if presentations[toViewController] == nil {
				presentations[toViewController] = toViewController.defaultPresentation ?? presentation
			}
			if needsSetup && !visibleControllers.toInsert.contains(toViewController) {
				reenteredVisible.append(toViewController)
			}
		}

		content.layoutIfNeeded()

		// Add views for new visible controllers (toInsert + re-entered).
		for toViewController in visibleControllers.toInsert + reenteredVisible {
			let ctx = context(toViewController)
			ctx.container.addSubview(ctx.view, layout: ctx.environment.contentLayout)
		}

		// Iterate only visible controllers for z-ordering and animation.
		let allVisible = visibleControllers.all(direction)
		allVisible.map(container).forEach(content.bringSubviewToFront)

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
			let currentPresentation = presentations[controller, default: presentation]
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
				(context(vc), presentations[vc, default: presentation].transition)
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
				#if VDPRESENT_LOG
				print("[prepareInteractive] setting activeTransitionUpdate, had existing=\(self?.activeTransitionUpdate != nil)")
				#endif
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
		// Completion for visible controllers only.
		for controller in visibleControllers.all(direction) {
			let currentPresentation = presentations[controller, default: presentation]
			currentPresentation.transition.completion(context(controller), isCompleted)
		}
		viewControllers = isCompleted ? controllers.to : controllers.from
		if isCompleted {
			configureInteractivity(
				presentation: presentation,
				controllers: controllers,
				context: context
			)

			// Controllers leaving visible zone but staying in full stack:
			// remove wrapper/container so they don't consume resources.
			// Must run before didSetViewControllers which calls updateContainers
			// (otherwise container(for:) would recreate a container we just removed).
			let visibleToSet = Set(visibleControllers.to.map(ObjectIdentifier.init))
			let fullToSet = Set(controllers.to.map(ObjectIdentifier.init))
			for vc in visibleControllers.from {
				let id = ObjectIdentifier(vc)
				if !visibleToSet.contains(id) && fullToSet.contains(id) {
					wrappers[vc]?.removeFromSuperview()
					wrappers[vc] = nil
					containers[vc]?.removeFromSuperview()
					containers[vc] = nil
				}
			}
		}

		didSetViewControllers()
		if !controllers.isTopTheSame {
			controllers.to.last?.endAppearanceTransition()
			controllers.from.last?.endAppearanceTransition()
		}
		if isCompleted {
			for fromViewController in controllers.toRemove {
				fromViewController.removeFromParent()
				fromViewController.didMove(toParent: nil)
			}
		} else {
			statusBarStyle = controllers.from.last?.preferredStatusBarStyle ?? statusBarStyle
			for toViewController in controllers.toInsert {
				toViewController.willMove(toParent: nil)
				toViewController.removeFromParent()
				toViewController.didMove(toParent: nil)
			}
		}
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
			presentations[item, default: presentation]
				.interactivity?.uninstall(context: context(item))
		}
		// Install for all `to` controllers, not just toInsert.
		// Controllers re-entering the visible zone get new containers,
		// so their gesture recognizers must be reinstalled.
		for controller in controllers.to {
			let ctxt = context(controller)
			presentations[controller, default: presentation]
				.interactivity?.install(context: ctxt) { [weak self] context, state in
					guard let self else { return .prevent }
					switch state {
					case .begin:
						guard !self.isSettingControllers else { return .prevent }
						let controllers = context.viewControllers
						let resolve: (UIViewController) -> UIPresentation = {
							self.presentations[$0] ?? $0.defaultPresentation ?? presentation
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
					#if VDPRESENT_LOG
					print("[Interactivity] dispatching state=\(state) hasActiveTransition=\(self.activeTransitionUpdate != nil)")
					#endif
					self.activeTransitionUpdate?(state)
					return .allow
				}
		}
	}
}

private extension UIStackController {

	func didSetViewControllers() {
		let set = Set(viewControllers)
		containers = containers.filter { set.contains($0.key) }
		wrappers = wrappers.filter { set.contains($0.key) }
		presentations = presentations.filter { set.contains($0.key) }
		updateContainers()
	}

	func wrapper(for controller: UIViewController) -> UIStackEffectView {
		wrappers[controller] ?? UIStackEffectView(controller.view)
	}

	@discardableResult
	func container(for controller: UIViewController) -> UIStackControllerCanvas {
		if let result = containers[controller] {
			return result
		}
		let container = UIStackControllerCanvas()
		container.backgroundColor = .clear
		containers[controller] = container
		content.containers.append(container)
		return container
	}

	func updateContainers() {
		// Only include containers that already exist — non-visible controllers
		// may have had their containers intentionally removed.
		content.containers = viewControllers.compactMap { containers[$0] }
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

// MARK: - Debug logging

#if VDPRESENT_LOG
/// Logs a summary of each visible controller's transform state after a phase.
///
/// Output format — one line per VC:
/// ```
/// [phase] Menu: center (layers=5, remaining)
/// [phase] Screen 1: ty=-23 sx=0.940 (layers=4, departing)
/// ```
private func logTransitionState(
	_ phase: String,
	allVisible: [UIViewController],
	controllers: UIPresentation.Context.Controllers,
	context: @escaping (UIViewController) -> UIPresentation.Context
) {
	let toRemove = Set(controllers.toRemove.map(ObjectIdentifier.init))
	let toSet = Set(controllers.to.map(ObjectIdentifier.init))
	var lines: [String] = []
	for vc in allVisible {
		let ctx = context(vc)
		let name = vc.view.accessibilityIdentifier ?? String(describing: type(of: vc))
		let transform = fmtTransform(ctx.view)
		let id = ObjectIdentifier(vc)
		let role: String
		if toRemove.contains(id) {
			role = "departing"
		} else if !toSet.contains(id) {
			role = "inserting"
		} else {
			role = "remaining"
		}
		let frame = fmtFrame(ctx.view)
		lines.append("  \(name): \(transform) \(frame) \(role)")
	}
	print("[\(phase)]\n\(lines.joined(separator: "\n"))")
}

private func fmtTransform(_ view: UIView) -> String {
	let t = view.affineTransform
	let sx = sqrt(t.a * t.a + t.c * t.c)
	let sy = sqrt(t.b * t.b + t.d * t.d)
	var parts: [String] = []
	if t.tx != 0 { parts.append("tx=\(Int(t.tx))") }
	if t.ty != 0 { parts.append("ty=\(Int(t.ty))") }
	if abs(sx - 1) > 0.001 || abs(sy - 1) > 0.001 {
		parts.append("sx=\(String(format: "%.3f", sx)) sy=\(String(format: "%.3f", sy))")
	}
	return parts.isEmpty ? "center" : parts.joined(separator: " ")
}

/// Window-relative insets: only non-zero edges, e.g. "{t=59 b=34}" or "{l=10 r=10 b=802}".
private func fmtFrame(_ view: UIView) -> String {
	guard let window = view.window else { return "{detached}" }
	let r = view.convert(view.bounds, to: nil)
	let wb = window.bounds
	var parts: [String] = []
	let t = Int(r.minY)
	let b = Int(wb.maxY - r.maxY)
	let l = Int(r.minX)
	let ri = Int(wb.maxX - r.maxX)
	if t != 0 { parts.append("t=\(t)") }
	if l != 0 { parts.append("l=\(l)") }
	if ri != 0 { parts.append("r=\(ri)") }
	if b != 0 { parts.append("b=\(b)") }
	return "{\(parts.isEmpty ? "full" : parts.joined(separator: " "))}"
}

/// Window-relative insets from presentation layer frame, same format as fmtFrame.
private func fmtPresentationFrame(_ pLayer: CALayer, in view: UIView) -> String {
	guard let window = view.window else { return "{detached}" }
	// presentation() frame is in superlayer coords — convert to window.
	let r: CGRect
	if let superlayer = pLayer.superlayer {
		r = superlayer.convert(pLayer.frame, to: nil)
	} else {
		r = pLayer.frame
	}
	let wb = window.bounds
	var parts: [String] = []
	let t = Int(r.minY)
	let b = Int(wb.maxY - r.maxY)
	let l = Int(r.minX)
	let ri = Int(wb.maxX - r.maxX)
	if t != 0 { parts.append("t=\(t)") }
	if l != 0 { parts.append("l=\(l)") }
	if ri != 0 { parts.append("r=\(ri)") }
	if b != 0 { parts.append("b=\(b)") }
	return "{\(parts.isEmpty ? "full" : parts.joined(separator: " "))}"
}

private func fmtCATransform(_ t: CGAffineTransform) -> String {
	let sx = sqrt(t.a * t.a + t.c * t.c)
	let sy = sqrt(t.b * t.b + t.d * t.d)
	var parts: [String] = []
	if t.tx != 0 { parts.append("tx=\(Int(t.tx))") }
	if t.ty != 0 { parts.append("ty=\(Int(t.ty))") }
	if abs(sx - 1) > 0.001 || abs(sy - 1) > 0.001 {
		parts.append("sx=\(String(format: "%.3f", sx)) sy=\(String(format: "%.3f", sy))")
	}
	return parts.isEmpty ? "center" : parts.joined(separator: " ")
}
#endif
