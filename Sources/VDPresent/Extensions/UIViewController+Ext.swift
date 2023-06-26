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
}
