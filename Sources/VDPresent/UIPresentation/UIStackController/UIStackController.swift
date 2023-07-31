import UIKit
import VDTransition

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
        let isTheSame = newViewControllers.last === viewControllers.last && !prsnt.environment.overCurrentContext
        
		transition(
            direction: direction ?? (isInsertion ? .insertion : .removal),
			to: newViewControllers,
			from: viewControllers,
			presentation: prsnt,
			animated: animated && !isTheSame,
            isInteractive: false,
            completion: completion
        )
	}
    
    open func wrap(view: UIView) -> UIStackViewWrapper {
        UIStackViewWrapper(view)
    }
}

public extension UIStackController {

	func show(
		_ viewController: UIViewController,
		as presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (() -> Void)? = nil
	) {
        if let i = viewControllers.firstIndex(where: viewController.isDescendant) {
            if let child = viewController.stackController, child !== self {
                child.show(as: presentation, animated: animated, completion: completion)
            } else {
                set(
                    viewControllers: Array(viewControllers.prefix(through: i)),
                    as: presentation,
                    animated: animated,
                    completion: completion
                )
            }
		} else {
			set(
				viewControllers: viewControllers + [viewController],
				as: presentation,
				animated: animated,
				completion: completion
			)
		}
	}
    
    func hideTop(
        _ count: Int = 1,
        as presentation: UIPresentation? = nil,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        set(
            viewControllers: Array(viewControllers.dropLast(count)),
            as: presentation,
            animated: animated,
            completion: completion
        )
    }
}

public extension UIStackController {

	static var root: UIStackController? {
		UIWindow.key?.rootViewController?
			.selfAndAllPresented.compactMap { $0 as? UIStackController }.first
	}

	static var top: UIStackController? {
		UIWindow.key?.rootViewController?
			.selfAndAllPresented.compactMap { $0 as? UIStackController }.last?.topStackControllerOrSelf
	}

	var topStackController: UIStackController? {
		let lastPresentation = viewControllers.last?.selfAndAllChildren.compactMap { $0 as? UIStackController }.last
		let top = lastPresentation?.topStackController ?? lastPresentation
		guard presentedViewController == nil else {
			return allPresented.compactMap { $0 as? UIStackController }.last?.topStackController ?? top
		}
		return top
	}

	var topStackControllerOrSelf: UIStackController {
        topStackController ?? self
	}

	var topViewController: UIViewController? {
		get { viewControllers.last }
		set {
			if let newValue {
				show(newValue)
            } else {
                hideTop(viewControllers.count)
            }
		}
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
        
        let allControllers = controllers.all(direction)
        allControllers.suffix(2).map(container).forEach(content.bringSubviewToFront)
        
        for toViewController in controllers.to where toViewController.parent == nil {
            toViewController.willMove(toParent: self)
            self.addChild(toViewController)
            toViewController.didMove(toParent: self)
        }
        
        controllers.toRemove.forEach {
            $0.willMove(toParent: nil)
        }
        
        var count = 0
        
        allControllers.forEach { controller in
            let currentPresentation = presentations[controller, default: presentation]
            currentPresentation.transition.prepare(context: context(controller))
        }
        allControllers.forEach { controller in
            let currentPresentation = presentations[controller, default: presentation]
            currentPresentation.transition
                .animate(context: context(controller)) { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .begin:
                        if !controllers.isTopTheSame {
                            if controller === controllers.to.last {
                                controller.beginAppearanceTransition(true, animated: animated)
                            }
                            if controller === controllers.from.last {
                                controller.beginAppearanceTransition(false, animated: animated)
                            }
                        }
                    case let .prepareInteractive(update):
                        self.animators[controller] = update
                    case let .end(completed):
                        count += 1
                        if count == allControllers.count {
                            self.completionBlock(
                                presentation: currentPresentation,
                                direction: direction,
                                controllers: controllers,
                                context: context,
                                isCompleted: completed,
                                completion: completion
                            )
                        }
                    }
                }
        }
    }
    
    func completionBlock(
        presentation: UIPresentation,
        direction: TransitionDirection,
        controllers: UIPresentation.Context.Controllers,
        context: @escaping (UIViewController) -> UIPresentation.Context,
        isCompleted: Bool,
        completion: (() -> Void)?
    ) {
        controllers.all(direction).forEach { controller in
            let currentPresentation = presentations[controller, default: presentation]
            currentPresentation.transition.completion(context: context(controller), completed: isCompleted)
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
        var animated: Bool
        var completion: (() -> Void)?
    }
}
