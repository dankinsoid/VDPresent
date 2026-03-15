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
/// stack.show(HomeViewController())
///
/// // Push with a custom presentation
/// stack.show(DetailViewController(), as: .sheet)
///
/// // Pop one level
/// stack.hide()
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
/// myViewController.show(as: .push, animated: true) {
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
/// myViewController.defaultPresentation = .push
/// myViewController.show()           // uses .push automatically
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
/// stack.show(DetailViewController(), as: .sheet)
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
	private var containers: [UIViewController: UIStackControllerContainer] = [:]
	private var wrappers: [UIViewController: UIStackViewWrapper] = [:]
	private var presentations: [UIViewController: UIPresentation] = [:]
	private var animators: [UIViewController: (UIPresentation.Interactivity.State) -> Void] = [:]
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
		show(vc)
	}

	override open func showDetailViewController(_ vc: UIViewController, sender: Any?) {
		show(vc)
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
		completion: (() -> Void)? = nil
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

	open func wrap(view: UIView) -> UIStackViewWrapper {
		UIStackViewWrapper(view)
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

		let context: (UIViewController) -> UIPresentation.Context = { [weak self, presentations, cache] in
			UIPresentation.Context(
				direction: direction,
				controller: $0,
				container: { [weak self] in self?.container(for: $0) ?? UIStackControllerContainer() },
				fromViewControllers: fromViewControllers,
				toViewControllers: toViewControllers,
				views: { [weak self] in self?.wrapper(for: $0) ?? UIStackViewWrapper($0.view) },
				animated: animated,
				animation: (presentations[$0] ?? presentation).animation,
				isInteractive: isInteractive,
				cache: cache,
				updateStatusBar: { [weak self] in
					self?.statusBarAnimation = $1
					self?.statusBarStyle = $0
				},
				environment: { presentations[$0]?.environment ?? presentation.environment }
			)
		}
		transition(
			presentation: presentation,
			direction: direction,
			animated: animated,
			controllers: controllers,
			context: context,
			completion: completion
		)
	}

	func transition(
		presentation: UIPresentation,
		direction: TransitionDirection,
		animated: Bool,
		controllers: UIPresentation.Context.Controllers,
		context: @escaping (UIViewController) -> UIPresentation.Context,
		completion: (() -> Void)?
	) {
		isSettingControllers = true
		viewControllers = controllers.to
		for toViewController in controllers.toInsert {
			if wrappers[toViewController] == nil {
				wrappers[toViewController] = wrap(view: toViewController.view)
			}
			if containers[toViewController] == nil {
				container(for: toViewController)
			}
			if presentations[toViewController] == nil {
				presentations[toViewController] = presentation
			}
		}
		
		controllers.all(direction, order: .zIndex).map(container).forEach(content.bringSubviewToFront)
		let allControllers = controllers.all(direction, order: .animation)
		
		for toViewController in controllers.to where toViewController.parent == nil {
			toViewController.willMove(toParent: self)
			self.addChild(toViewController)
			toViewController.didMove(toParent: self)
		}
		
		controllers.toRemove.forEach {
			$0.willMove(toParent: nil)
		}
		
		allControllers.forEach { controller in
			let currentPresentation = presentations[controller, default: presentation]
			AnimationDriver.prepare(
				transition: currentPresentation.transition,
				context: context(controller)
			)
		}
		
		print("[UIStackController] allControllers: \(allControllers.map { $0.view.accessibilityIdentifier ?? "nil" })")
		AnimationDriver.animate(
			allControllers.map { controller in
				(context(controller), presentations[controller, default: presentation].transition)
			},
			beginAppearance: {
				if !controllers.isTopTheSame {
					for controller in allControllers {
						if controller === controllers.to.last {
							controller.beginAppearanceTransition(true, animated: animated)
						}
						if controller === controllers.from.last {
							controller.beginAppearanceTransition(false, animated: animated)
						}
					}
				}
			},
			prepareInteractive: { [weak self] update in
				for controller in allControllers {
					self?.animators[controller] = update
				}
			},
			completion: { [weak self] completed in
				self?.completionBlock(
					presentation: presentation,//currentPresentation,
					direction: direction,
					controllers: controllers,
					context: context,
					isCompleted: completed,
					completion: completion
				)
			}
		)
	}

	func completionBlock(
		presentation: UIPresentation,
		direction: TransitionDirection,
		controllers: UIPresentation.Context.Controllers,
		context: @escaping (UIViewController) -> UIPresentation.Context,
		isCompleted: Bool,
		completion: (() -> Void)?
	) {
		controllers.all(direction, order: .animation).forEach { controller in
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
		controllers.toRemove.forEach {
			presentations[$0, default: presentation]
				.interactivity?.uninstall(context: context($0))
		}
		controllers.toInsert.forEach { controller in
			let ctxt = context(controller)
			presentations[controller, default: presentation]
				.interactivity?.install(context: ctxt) { [weak self] context, state in
					guard let self else { return .prevent }
					switch state {
					case .begin:
						guard !self.isSettingControllers else { return .prevent }
						self.transition(
							presentation: presentation,
							direction: context.direction,
							animated: context.animated,
							controllers: context.viewControllers,
							context: context.for,
							completion: nil
						)

					default:
						break
					}
					self.animators.forEach {
						$0.value(state)
					}
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
		animators = animators.filter { set.contains($0.key) }
		updateContainers()
	}

	func wrapper(for controller: UIViewController) -> UIStackViewWrapper {
		wrappers[controller] ?? UIStackViewWrapper(controller.view)
	}

	@discardableResult
	func container(for controller: UIViewController) -> UIStackControllerContainer {
		if let result = containers[controller] {
			return result
		}
		let container = UIStackControllerContainer()
		container.backgroundColor = .clear
		containers[controller] = container
		content.containers.append(container)
		return container
	}

	func updateContainers() {
		content.containers = viewControllers.map(container)
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
