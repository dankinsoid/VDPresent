import UIKit
import VDTransition

open class UIStackController: UIViewController {

    public private(set) var viewControllers: [UIViewController] = []
	public var presentation: UIPresentation?

	override open var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

    private let content = UIStackControllerView()
    private var containers: [UIViewController: UIStackControllerContainerView] = [:]
    private var wrappers: [UIViewController: UIView] = [:]
	private let cache = UIPresentation.Context.Cache()

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
		presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (() -> Void)? = nil
	) {
		guard newViewControllers != viewControllers else {
			completion?()
			return
		}
        
        let isEmpty = newViewControllers.isEmpty
        if isEmpty, self === UIWindow.key?.rootViewController {
            completion?()
            return
        }

		let isInsertion = newViewControllers.last.map { !viewControllers.contains($0) } ?? false

		makeTransition(
			to: newViewControllers,
			from: viewControllers,
			presentation: presentation ?? self.presentation(for: isInsertion ? newViewControllers.last : viewControllers.last),
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
		presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (() -> Void)? = nil
	) {
		if let i = viewControllers.firstIndex(of: viewController) {
			set(
				viewControllers: Array(viewControllers.prefix(through: i)),
				presentation: presentation,
				animated: animated,
				completion: completion
			)
		} else {
			set(
				viewControllers: viewControllers + [viewController],
				presentation: presentation,
				animated: animated,
				completion: completion
			)
		}
	}
}

public extension UIStackController {

	static var root: UIStackController? {
		UIWindow.key?.rootViewController?
			.selfAndAllPresented.compactMap { $0 as? UIStackController }.first
	}

	static var top: UIStackController? {
		UIWindow.key?.rootViewController?
			.selfAndAllPresented.compactMap { $0 as? UIStackController }.last?.topOrSelf
	}

	var top: UIStackController? {
		let lastPresentation = viewControllers.last?.selfAndAllChildren.compactMap { $0 as? UIStackController }.last
		let top = lastPresentation?.top ?? lastPresentation
		guard presentedViewController == nil else {
			return allPresented.compactMap { $0 as? UIStackController }.last?.top ?? top
		}
		return top
	}

	var topOrSelf: UIStackController {
		top ?? self
	}

	var visibleViewController: UIViewController? {
		get { viewControllers.last }
		set {
			if let newValue {
				show(newValue)
			}
		}
	}
}

private extension UIStackController {

	func presentation(
		for viewController: UIViewController?
	) -> UIPresentation {
		viewController?.defaultPresentation ?? presentation ?? .default
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
            cache: cache
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
			guard let self else { return }
            for toViewController in context.viewControllersToInsert {
                if wrappers[toViewController] == nil {
                    wrappers[toViewController] = wrap(view: toViewController.view)
                }
                if containers[toViewController] == nil {
                    container(for: toViewController)
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

		let animation: () -> Void = {
            if !context.isInteractive {
                context.toViewControllers.last?.beginAppearanceTransition(true, animated: context.animated)
                context.fromViewControllers.last?.beginAppearanceTransition(false, animated: context.animated)
            }
            presentation.transition.update(context: context, state: .change(context.direction.at(1)))
		}

		let completion: (Bool) -> Void = { [weak self] isCompleted in
			guard let self else { return }
            self.viewControllers = isCompleted ? context.toViewControllers : context.fromViewControllers
            if isCompleted {
                self.afterTransition(
                    presentation: presentation,
                    context: context
                )
            }
			presentation.transition.update(context: context, state: .end(completed: isCompleted))
            
            self.didSetViewControllers()
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
			completion?()
		}

		return (prepare, animation, completion)
	}

	func afterTransition(
		presentation: UIPresentation,
        context: UIPresentation.Context
	) {
        var prepare: () -> Void = {}
        var completion: (Bool) -> Void = { _ in }
        
        context.viewControllersToRemove.forEach {
            presentation.interactivity?.uninstall(context: context, for: $0)
        }
        
		presentation.interactivity?.install(context: context) { [weak self] context, state in
            guard let self else { return }
			switch state {
			case .begin:
                (prepare, _, completion) = self.transitionBlocks(
                    presentation: presentation,
                    context: context,
                    completion: nil
                )
                prepare()
                presentation.transition.update(context: context, state: state)
                
			case .change:
                presentation.transition.update(context: context, state: state)
                
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
		}
	}
}

private extension UIStackController {
    
    func didSetViewControllers() {
        let set = Set(viewControllers)
        containers = containers.filter { set.contains($0.key) }
        wrappers = wrappers.filter { set.contains($0.key) }
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
