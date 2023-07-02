import UIKit
import VDTransition

open class UIStackController: UIViewController {

    public private(set) var viewControllers: [UIViewController] = []
    public private(set) var isSettingControllers = false
	public var presentation: UIPresentation?

	override open var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

    private let content = UIStackControllerView()
    private var containers: [UIViewController: UIStackControllerContainerView] = [:]
    private var wrappers: [UIViewController: UIView] = [:]
    private var presentations: [UIViewController: UIPresentation] = [:]
    private let cache = UIPresentation.Context.Cache()
    private var queue: [Setting] = []
    private var animator: Animator?

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

	override open func targetViewController(forAction action: Selector, sender: Any?) -> UIViewController? {
		super.targetViewController(forAction: action, sender: sender)
	}

	open func set(
		viewControllers newViewControllers: [UIViewController],
		as presentation: UIPresentation? = nil,
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

		makeTransition(
			to: newViewControllers,
			from: viewControllers,
			presentation: presentation ?? self.presentation(for: isInsertion ? newViewControllers : viewControllers),
			animated: animated,
            completion: completion
        )
	}
    
    open func wrap(view: UIView) -> UIView {
        view
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
            return .fullScreen
        }
        return viewControllers.last?.defaultPresentation ?? presentation ?? .default
	}
}

private extension UIStackController {

	func makeTransition(
		to toViewControllers: [UIViewController],
		from fromViewControllers: [UIViewController],
		presentation: UIPresentation,
		animated: Bool,
		completion: (() -> Void)?
	) {
		let (prepare, animation, completion) = transitionBlocks(
			to: toViewControllers,
			from: fromViewControllers,
			presentation: presentation,
			animated: animated,
            isInteractive: false,
			completion: completion
		)
		prepare()
		if animated {
			UIView.animate(with: presentation.animation) {
				animation()
			} completion: { isCompleted in
				completion(isCompleted)
			}
		} else {
			animation()
			completion(true)
		}
	}

    func transitionBlocks(
        to toViewControllers: [UIViewController],
        from fromViewControllers: [UIViewController],
        presentation: UIPresentation,
        animated: Bool,
        isInteractive: Bool,
        completion: (() -> Void)?
    ) -> (
        prepare: () -> Void,
        animation: () -> Void,
        completion: (Bool) -> Void
    ) {
        let controllers = UIPresentation.Context.Controllers(
            fromViewControllers: fromViewControllers,
            toViewControllers: toViewControllers
        )
        let context: (UIViewController) -> UIPresentation.Context = { [cache] in
            UIPresentation.Context(
                controller: $0,
                container: { [weak self] in self?.container(for: $0) ?? UIStackControllerContainerView() },
                fromViewControllers: fromViewControllers,
                toViewControllers: toViewControllers,
                views: { [weak self] in self?.wrapper(for: $0) ?? $0.view },
                animated: animated,
                animation: presentation.animation,
                isInteractive: isInteractive,
                cache: cache,
                environment: presentation.environment
            )
        }
        return transitionBlocks(
            presentation: presentation,
            animated: animated,
            controllers: controllers,
            context: context,
            completion: completion
        )
    }
    
    func transitionBlocks(
        presentation: UIPresentation,
        animated: Bool,
        controllers: UIPresentation.Context.Controllers,
        context: @escaping (UIViewController) -> UIPresentation.Context,
        completion: (() -> Void)?
    ) -> (
        prepare: () -> Void,
        animation: () -> Void,
        completion: (Bool) -> Void
    ) {
		let prepare: () -> Void = { [weak self] in
            self?.prepareBlock(presentation: presentation, controllers: controllers, context: context)
		}

		let animation: () -> Void = { [weak self] in
            self?.animationBlock(presentation: presentation, animated: animated, controllers: controllers, context: context)
		}

		let completion: (Bool) -> Void = { [weak self] in
            self?.completionBlock(
                presentation: presentation,
                controllers: controllers,
                context: context,
                isCompleted: $0,
                completion: completion
            )
		}

		return (prepare, animation, completion)
	}
    
    func prepareBlock(
        presentation: UIPresentation,
        controllers: UIPresentation.Context.Controllers,
        context: @escaping (UIViewController) -> UIPresentation.Context
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
        
        let allControllers = controllers.all
        allControllers.suffix(2).map(container).forEach(content.bringSubviewToFront)
        
        allControllers.forEach {
            presentations[$0, default: presentation].transition.update(context: context($0), state: .begin)
        }
        
        for toViewController in controllers.to where toViewController.parent == nil {
            toViewController.willMove(toParent: self)
            self.addChild(toViewController)
            toViewController.didMove(toParent: self)
        }
        
        controllers.toRemove.forEach {
            $0.willMove(toParent: nil)
        }
     
        allControllers.forEach {
            presentations[$0, default: presentation]
                .transition.update(context: context($0), state: .change(.start))
        }
    }
    
    func animationBlock(
        presentation: UIPresentation,
        animated: Bool,
        controllers: UIPresentation.Context.Controllers,
        context: @escaping (UIViewController) -> UIPresentation.Context
    ) {
        controllers.to.last?.beginAppearanceTransition(true, animated: animated)
        controllers.from.last?.beginAppearanceTransition(false, animated: animated)
        
        controllers.all.forEach {
            presentations[$0, default: presentation]
                .transition.update(context: context($0), state: .change(.end))
        }
    }
    
    func completionBlock(
        presentation: UIPresentation,
        controllers: UIPresentation.Context.Controllers,
        context: @escaping (UIViewController) -> UIPresentation.Context,
        isCompleted: Bool,
        completion: (() -> Void)?
    ) {
        viewControllers = isCompleted ? controllers.to : controllers.from
        if isCompleted {
            configureInteractivity(
                presentation: presentation,
                controllers: controllers,
                context: context
            )
        }
        
        controllers.all.forEach {
            presentations[$0, default: presentation]
                .transition.update(context: context($0), state: .end(completed: isCompleted))
        }
        
        didSetViewControllers()
        controllers.to.last?.endAppearanceTransition()
        controllers.from.last?.endAppearanceTransition()
        if isCompleted {
            for fromViewController in controllers.toRemove {
                fromViewController.removeFromParent()
                fromViewController.didMove(toParent: nil)
            }
        } else {
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
                        let (prepare, animate, completion) = self.transitionBlocks(
                            presentation: presentation,
                            animated: context.animated,
                            controllers: context.viewControllers,
                            context: context.for,
                            completion: nil
                        )
                        prepare()
                        let animator = Animator()
                        self.animator = animator
                        animator.addAnimations(animate)
                        animator.addCompletion { [weak self] position in
                            completion(position == .end)
                            self?.animator?.finishAnimation(at: position == .end ? .end : .start)
                            self?.animator = nil
                        }
                        animator.startAnimation()
                        animator.pauseAnimation()
                        
                    case let .change(progress):
                        self.animator?.fractionComplete = progress.value
                        
                    case let .end(completed, duration):
                        self.animator?.isReversed = !completed
                        self.animator?.continueAnimation(duration: duration)
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
        updateContainers()
    }
        
    func wrapper(for controller: UIViewController) -> UIView {
        wrappers[controller] ?? controller.view
    }
    
    @discardableResult
    func container(for controller: UIViewController) -> UIStackControllerContainerView {
        if let result = containers[controller] {
            return result
        }
        if let result = wrapper(for: controller) as? UIStackControllerContainerView {
            return result
        }
        let container = UIStackControllerContainerView()
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
