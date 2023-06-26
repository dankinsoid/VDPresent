import UIKit
import VDTransition

open class UIStackController: UIViewController {

	public private(set) var viewControllers: [UIViewController] = []
	public var presentation: UIPresentation?

	override open var shouldAutomaticallyForwardAppearanceMethods: Bool { false }

	private var cache = UIPresentation.Context.Cache()

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

		let isInsertion = newViewControllers.last.map { !viewControllers.contains($0) } ?? false

		makeTransition(
			to: newViewControllers,
			from: viewControllers,
			presentation: presentation ?? self.presentation(for: isInsertion ? newViewControllers.last : viewControllers.last),
			direction: isInsertion ? .insertion : .removal,
			animated: animated,
			completion: completion
		)
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
		completion: (() -> Void)?
	) -> (
		prepare: () -> Void,
		animation: () -> Void,
		completion: (Bool) -> Void
	) {

		var context = UIPresentation.Context(
			direction: direction,
			container: view,
			fromViewControllers: fromViewControllers,
			toViewControllers: toViewControllers,
			animated: animated,
			isInteractive: false,
			cache: cache
		)

		let prepare: () -> Void = { [weak self] in
			guard let self else { return }

			presentation.transition.update(context: &context, state: .begin)

			for toViewController in context.toViewControllers where toViewController.parent == nil {
				toViewController.willMove(toParent: self)
				self.addChild(toViewController)
				toViewController.didMove(toParent: self)
			}

			context.viewControllersToRemove.forEach {
				$0.willMove(toParent: nil)
			}
			self.view.setNeedsLayout()
			self.view.layoutIfNeeded()
		}

		let animation: () -> Void = { [weak self] in
			guard let self else { return }

			context.toViewControllers.last?.beginAppearanceTransition(true, animated: animated)
			context.fromViewControllers.last?.beginAppearanceTransition(false, animated: animated)
			presentation.transition.update(context: &context, state: .change(direction.at(1)))
			self.view.setNeedsLayout()
			self.view.layoutIfNeeded()
		}

		let completion: (Bool) -> Void = { [weak self] isCompleted in
			guard let self else { return }
			self.viewControllers = toViewControllers

			self.afterTransition(presentation: presentation)
			presentation.transition.update(context: &context, state: .end(completed: isCompleted))
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
		presentation: UIPresentation
	) {
		var context = UIPresentation.Context(
			direction: .removal,
			container: view,
			fromViewControllers: viewControllers,
			toViewControllers: viewControllers.dropLast(),
			animated: true,
			isInteractive: true,
			cache: cache
		)
		var animator: UIViewPropertyAnimator?
		presentation.interactivity?.install(context: &context) { state in
			switch state {
			case .begin:
				presentation.transition.update(context: &context, state: .begin)
				animator = Animator()
				animator?.addAnimations {
					presentation.transition.update(context: &context, state: .change(.removal(.end)))
				}
				animator?.addCompletion { _ in
				}

			case let .change(progress):
				animator?.fractionComplete = progress.progress

			case let .end(completed):
				animator?.finishAnimation(at: completed ? .end : .start)
				animator = nil
			}
			presentation.transition.update(context: &context, state: state)
		}
	}
}
