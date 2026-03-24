import UIKit

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
				push(newValue)
			} else {
				pop(viewControllers.count)
			}
		}
	}
}

public extension UIStackController {

	/// Pushes a view controller onto the stack.
	///
	/// If the controller is already in the stack, pops back to it instead of adding a duplicate.
	/// If it belongs to a nested ``UIStackController``, forwards the presentation to that child stack.
	///
	/// ```swift
	/// stack.push(DetailViewController())
	/// stack.push(DetailViewController(), as: .navigation)
	/// stack.push(DetailViewController(), as: .pageSheet) {
	///     print("presented")
	/// }
	/// ```
	///
	/// - Parameters:
	///   - viewController: The controller to push.
	///   - presentation: Transition style to use. Falls back to the controller's ``UIViewController/defaultPresentation`` or the stack's default.
	///   - animated: Whether to animate the transition.
	///   - completion: Called after the transition finishes.
	func push(
		_ viewController: UIViewController,
		as presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (@MainActor () -> Void)? = nil
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

	/// Removes one or more controllers from the top of the stack.
	///
	/// ```swift
	/// stack.pop()       // pop one
	/// stack.pop(3)      // pop last three
	/// stack.pop(-1)     // pop to root (keep first controller)
	/// ```
	///
	/// - Parameters:
	///   - count: Number of controllers to remove.
	///     Positive values pop from the top (e.g. `pop(2)` removes the last two).
	///     Negative values keep that many from the bottom (e.g. `pop(-1)` pops to root).
	///   - presentation: Transition style for the dismissal animation.
	///   - animated: Whether to animate the transition.
	///   - completion: Called after the transition finishes.
	func pop(
		_ count: Int = 1,
		as presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (@MainActor () -> Void)? = nil
	) {
		set(
			viewControllers: count < 0 ? Array(viewControllers.prefix(-count)) : Array(viewControllers.dropLast(count)),
			as: presentation,
			animated: animated,
			completion: completion
		)
	}

}
