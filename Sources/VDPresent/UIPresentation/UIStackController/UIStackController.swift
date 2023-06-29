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
    private var caches: [UIViewController: UIPresentation.Context.Cache] = [:]
    private var presentationStack: [Setting] = []

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
            presentationStack.append(
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
			direction: isInsertion ? .insertion : .removal,
			animated: animated
        ) { [weak self] in
            if isEmpty {
                self?.hide(animated: false, completion: completion)
            } else {
                completion?()
            }
        }
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
			set(
				viewControllers: Array(viewControllers.prefix(through: i)),
				as: presentation,
				animated: animated,
				completion: completion
			)
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
		direction: TransitionDirection,
		animated: Bool,
		completion: (() -> Void)?
	) {
		let (prepare, animation, completion) = transitionBlocks(
			to: toViewControllers,
			from: fromViewControllers,
			presentation: presentation,
			direction: direction,
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
        direction: TransitionDirection,
        animated: Bool,
        isInteractive: Bool,
        completion: (() -> Void)?
    ) -> (
        prepare: () -> Void,
        animation: () -> Void,
        completion: (Bool) -> Void
    ) {
        let context = UIPresentation.Context(
            direction: direction,
            container: { [weak self] in self?.container(for: $0) ?? UIStackControllerContainerView() },
            fromViewControllers: fromViewControllers,
            toViewControllers: toViewControllers,
            views: { [weak self] in self?.wrapper(for: $0) ?? $0.view },
            animated: animated,
            isInteractive: isInteractive,
            cache: cache(
                for: direction == .insertion
                    ? toViewControllers.last ?? UIViewController()
                    : fromViewControllers.last ?? UIViewController()
            )
        )
        return transitionBlocks(presentation: presentation, context: context, completion: completion)
    }
    
    func transitionBlocks(
        presentation: UIPresentation,
        context: UIPresentation.Context,
        completion: (() -> Void)?
    ) -> (
        prepare: () -> Void,
        animation: () -> Void,
        completion: (Bool) -> Void
    ) {
		let prepare: () -> Void = { [weak self] in
            self?.prepareBlock(presentation: presentation, context: context)
		}

		let animation: () -> Void = { [weak self] in
            self?.animationBlock(presentation: presentation, context: context)
		}

		let completion: (Bool) -> Void = { [weak self] in
            self?.completionBlock(presentation: presentation, context: context, isCompleted: $0, completion: completion)
		}

		return (prepare, animation, completion)
	}
    
    func prepareBlock(
        presentation: UIPresentation,
        context: UIPresentation.Context
    ) {
        isSettingControllers = true
        for toViewController in context.viewControllersToInsert {
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
        
        presentation.transition.update(context: context, state: .begin)
        
        for toViewController in context.toViewControllers where toViewController.parent == nil {
            toViewController.willMove(toParent: self)
            self.addChild(toViewController)
            toViewController.didMove(toParent: self)
        }
        
        context.viewControllersToRemove.forEach {
            $0.willMove(toParent: nil)
        }
        
        if context.isInteractive {
            context.toViewControllers.last?.beginAppearanceTransition(true, animated: context.animated)
            context.fromViewControllers.last?.beginAppearanceTransition(false, animated: context.animated)
        }
        
        presentation.transition.update(context: context, state: .change(context.direction.at(0)))
    }
    
    func animationBlock(
        presentation: UIPresentation,
        context: UIPresentation.Context
    ) {
        if !context.isInteractive {
            context.toViewControllers.last?.beginAppearanceTransition(true, animated: context.animated)
            context.fromViewControllers.last?.beginAppearanceTransition(false, animated: context.animated)
        }
        presentation.transition.update(context: context, state: .change(context.direction.at(1)))
    }
    
    func completionBlock(
        presentation: UIPresentation,
        context: UIPresentation.Context,
        isCompleted: Bool,
        completion: (() -> Void)?
    ) {
        viewControllers = isCompleted ? context.toViewControllers : context.fromViewControllers
        if isCompleted {
            configureInteractivity(
                presentation: presentation,
                context: context
            )
        }
        presentation.transition.update(context: context, state: .end(completed: isCompleted))
        
        didSetViewControllers()
        context.toViewControllers.last?.endAppearanceTransition()
        context.fromViewControllers.last?.endAppearanceTransition()
        if isCompleted {
            for fromViewController in context.viewControllersToRemove {
                fromViewController.removeFromParent()
                fromViewController.didMove(toParent: nil)
            }
        } else {
            for toViewController in context.viewControllersToInsert {
                toViewController.willMove(toParent: nil)
                toViewController.removeFromParent()
                toViewController.didMove(toParent: nil)
            }
        }
        isSettingControllers = false
        completion?()
        if let next = presentationStack.first {
            presentationStack.removeFirst()
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
        context: UIPresentation.Context
	) {
        var prepare: () -> Void = {}
        var completion: (Bool) -> Void = { _ in }
        presentation.interactivity?.uninstall(context: context)
		presentation.interactivity?.install(context: context) { [weak self] context, state in
            guard let self else { return .prevent }
			switch state {
			case .begin:
                guard !self.isSettingControllers else { return .prevent }
                (prepare, _, completion) = self.transitionBlocks(
                    presentation: presentation,
                    context: context,
                    completion: nil
                )
                prepare()
                presentation.transition.update(context: context, state: state)
                
			case let .change(progress):
                if progress.progress > 1 {
                    #warning("TODO")
                    presentation.transition.update(context: context, state: state)
                } else {
                    presentation.transition.update(context: context, state: state)
                }
                
			case let .end(completed, animation):
                let end: () -> Void = {
                    presentation.transition.update(context: context, state: state)
                    completion(completed)
                }
                if let animation {
                    UIView.animate(with: animation) {
                        presentation.transition.update(
                            context: context,
                            state: .change(context.direction.at(completed ? 1 : 0))
                        )
                    } completion: { _ in
                        end()
                    }
                } else {
                    end()
                }
			}
            return .allow
		}
	}
}

private extension UIStackController {
    
    func didSetViewControllers() {
        let set = Set(viewControllers)
        containers = containers.filter { set.contains($0.key) }
        wrappers = wrappers.filter { set.contains($0.key) }
        presentations = presentations.filter { set.contains($0.key) }
        caches = caches.filter { set.contains($0.key) }
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
    
    func cache(for controller: UIViewController) -> UIPresentation.Context.Cache {
        if let result = caches[controller] {
            return result
        }
        let cache = UIPresentation.Context.Cache()
        caches[controller] = cache
        return cache
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
