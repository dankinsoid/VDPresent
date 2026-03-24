import UIKit

public extension UIViewController {

	func present(animated: Bool = true, completion: (() -> Void)? = nil) {
		UIWindow.key?.rootViewController?.vcForPresent
			.present(self, animated: animated, completion: completion)
	}
}

extension UIViewController {

	var vcForPresent: UIViewController {
		presentedViewController?.vcForPresent ?? self
	}

	var selfAndAllPresented: [UIViewController] {
		[self] + allPresented
	}

	var allPresented: [UIViewController] {
		[presentedViewController].compactMap { $0 } + (presentedViewController?.allPresented ?? [])
	}

	var allChildren: [UIViewController] {
		children + children.flatMap(\.allChildren)
	}

	var selfAndAllChildren: [UIViewController] {
		[self] + allChildren
	}

	func isDescendant(of controller: UIViewController) -> Bool {
		self === controller || parent?.isDescendant(of: controller) == true
	}

	/// Stable identity used by ``UIStackController/set(path:id:create:as:animated:completion:)``
	/// to match path elements to existing view controllers across stack updates.
	var idForPath: AnyHashable? {
		get { objc_getAssociatedObject(self, &idForPathKey) as? AnyHashable }
		set { objc_setAssociatedObject(self, &idForPathKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
	}
}

private var idForPathKey = 0
