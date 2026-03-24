import UIKit

// @ai-generated(paired)

extension UIStackController {

	/// Declaratively sets the stack to match a collection of `Identifiable` path elements.
	///
	/// Reuses existing controllers whose ``UIViewController/idForPath`` matches an element's `id`.
	/// Creates new controllers via the `item` builder for unmatched elements.
	///
	/// ```swift
	/// struct Screen: Identifiable {
	///     let id: String
	///     let title: String
	/// }
	///
	/// let path = [Screen(id: "home", title: "Home"), Screen(id: "detail", title: "Detail")]
	/// stack.set(path: path) { screen in
	///     DetailViewController(title: screen.title)
	/// } update: { screen, vc in
	///     (vc as? DetailViewController)?.title = screen.title
	/// }
	/// ```
	///
	/// - Parameters:
	///   - path: The desired stack path. Each element maps to one controller.
	///   - item: Result builder that produces a ``ControllerItem`` for a given path element.
	///   - presentation: Transition style for the stack change animation.
	///   - animated: Whether to animate the transition.
	///   - completion: Called after the transition finishes.
	func `set`<T: Identifiable>(
		path: some Collection<T>,
		@ControllerItemBuilder item: @MainActor (T) -> ControllerItemConvertable,
		as presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (@MainActor () -> Void)? = nil
	) {
		self.set(
			path: path,
			id: \.id,
			item: item,
			as: presentation,
			animated: animated,
			completion: completion
		)
	}

	/// Declaratively sets the stack to match a collection of `Hashable` path elements,
	/// using each element itself as its identity.
	///
	/// ```swift
	/// enum Route: Hashable { case home, settings, profile }
	///
	/// stack.set(path: [.home, .settings]) { route in
	///     switch route {
	///     case .home:     return HomeViewController()
	///     case .settings: return SettingsViewController()
	///     case .profile:  return ProfileViewController()
	///     }
	/// }
	/// ```
	@_disfavoredOverload
	func `set`<T: Hashable>(
		path: some Collection<T>,
		@ControllerItemBuilder item: @MainActor (T) -> ControllerItemConvertable,
		as presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (@MainActor () -> Void)? = nil
	) {
		self.set(
			path: path,
			id: \.self,
			item: item,
			as: presentation,
			animated: animated,
			completion: completion
		)
	}

	/// Declaratively sets the stack to match a collection of path elements with a custom identity key.
	///
	/// For each element in `path`, looks up an existing controller by its stored ``UIViewController/idForPath``.
	/// If found, the controller is reused and updated; otherwise `item` produces a new one tagged with the element's id.
	///
	/// ```swift
	/// struct Step {
	///     let name: String
	///     let order: Int
	/// }
	///
	/// stack.set(path: steps, id: \.name) { step in
	///     StepViewController(step: step)
	/// } update: { step, vc in
	///     (vc as? StepViewController)?.update(with: step)
	/// }
	/// ```
	///
	/// - Parameters:
	///   - path: The desired stack path. Each element maps to one controller.
	///   - id: Extracts a stable identity from a path element.
	///   - item: Result builder that produces a ``ControllerItem`` for a given path element.
	///   - presentation: Transition style for the stack change animation.
	///   - animated: Whether to animate the transition.
	///   - completion: Called after the transition finishes.
	func `set`<T, ID: Hashable>(
		path: some Collection<T>,
		id: (T) -> ID,
		@ControllerItemBuilder item: @MainActor (T) -> ControllerItemConvertable,
		as presentation: UIPresentation? = nil,
		animated: Bool = true,
		completion: (() -> Void)? = nil
	) {
		let byIDs = viewControllers
			.compactMap { vc -> (ID, UIViewController)? in
				guard let idForPath = vc.idForPath?.base as? ID else { return nil }
				return (idForPath, vc)
			}
			.reduce(into: [:]) {
				$0[$1.0] = $1.1
			}
		var seen = Set<ID>()
		let controllers = path.compactMap { data -> UIViewController? in
			let dataID = id(data)
			guard seen.insert(dataID).inserted else {
				assertionFailure("Duplicate id \(dataID) in set(path:). Each element must have a unique identity.")
				return nil
			}
			let item = item(data).asControllerItem
			if let vc = byIDs[dataID] {
				item.update(vc)
				return vc
			} else {
				let vc = item.create()
				item.update(vc)
				vc.idForPath = dataID
				return vc
			}
		}
		set(viewControllers: controllers, as: presentation, animated: animated, completion: completion)
	}
}

protocol ControllerItemConvertable {

	@MainActor var asControllerItem: ControllerItem { get }
}

/// Pairs a create factory with an optional update closure for controller reuse in ``UIStackController/set(path:id:item:as:animated:completion:)``.
///
/// ```swift
/// // Create-only (no update needed):
/// ControllerItem(create: HomeViewController())
///
/// // With typed update:
/// ControllerItem(
///     create: DetailViewController(),
///     update: { vc in vc.title = "Updated" }
/// )
/// ```
struct ControllerItem: ControllerItemConvertable {

	let create: @MainActor () -> UIViewController
	let update: @MainActor (UIViewController) -> Void

	var asControllerItem: ControllerItem { self }

	init<Controller: UIViewController>(
		create: @escaping @autoclosure @MainActor () -> Controller,
		update: @escaping @MainActor (Controller) -> Void
	) {
		self.init(create: create, update: update)
	}

	init(
		create: @escaping @autoclosure @MainActor () -> UIViewController
	) {
		self.init(create: create, update: { _ in })
	}

	init<Controller: UIViewController>(
		create: @escaping @MainActor () -> Controller,
		update: @escaping @MainActor (Controller) -> Void
	) {
		self.create = create
		self.update = { vc in
			guard let controller = vc as? Controller else { return }
			update(controller)
		}
	}
}

@MainActor
@resultBuilder
enum ControllerItemBuilder {

	@inlinable
	static func buildBlock(_ components: [ControllerItem]...) -> [ControllerItem] {
		components.flatMap { $0 }
	}

	@inlinable
	static func buildExpression(_ expression: some ControllerItemConvertable) -> [ControllerItem] {
		[expression.asControllerItem]
	}

	@inlinable
	static func buildExpression(_ expression: any ControllerItemConvertable) -> [ControllerItem] {
		[expression.asControllerItem]
	}

	@inlinable
	static func buildExpression<C: UIViewController>(_ expression: @escaping @autoclosure () -> C) -> [ControllerItem] {
		[
			ControllerItem(create: expression())
		]
	}

	@inlinable
	static func buildOptional(_ component: [ControllerItem]?) -> [ControllerItem] {
		component ?? []
	}

	@inlinable
	static func buildEither(first component: [ControllerItem]) -> [ControllerItem] {
		component
	}

	@inlinable
	static func buildEither(second component: [ControllerItem]) -> [ControllerItem] {
		component
	}

	@inlinable
	static func buildArray(_ components: [[ControllerItem]]) -> [ControllerItem] {
		components.flatMap { $0 }
	}

	@inlinable
	static func buildLimitedAvailability(_ component: [ControllerItem]) -> [ControllerItem] {
		component
	}
}
