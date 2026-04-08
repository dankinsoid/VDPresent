import SwiftUI
import UIKit
import VDTransition

public struct UIViewTransition {

	public static let identity = UIViewTransition()

	public typealias TransitionClosure = @MainActor (UIView, _ identity: UIViewState) -> UIViewState

	public let isIdentity: Bool
	public let willAppear: TransitionClosure
	public let idle: TransitionClosure
	public let didDisappear: TransitionClosure
	
	public init() {
		self.isIdentity = true
		self.willAppear = { _, identity in identity }
		self.idle = { _, identity in identity }
		self.didDisappear = { _, identity in identity }
	}

	public init(
		willAppear: @escaping TransitionClosure,
		idle: @escaping TransitionClosure = { _, identity in identity },
		didDisappear: @escaping TransitionClosure
	) {
		self.isIdentity = false
		self.willAppear = willAppear
		self.idle = idle
		self.didDisappear = didDisappear
	}

	public init(
		idle: @escaping TransitionClosure = { _, identity in identity },
		removed: @escaping TransitionClosure
	) {
		self.init(willAppear: removed, idle: idle, didDisappear: removed)
	}
}

extension UIViewTransition {
	
	public struct Tween {
		
		public let from: UIViewTransition.TransitionClosure
		public let to: UIViewTransition.TransitionClosure
		
		public init(
			from: @escaping UIViewTransition.TransitionClosure,
			to: @escaping UIViewTransition.TransitionClosure
		) {
			self.from = from
			self.to = to
		}

		public static func combined(_ tweens: Tween...) -> Tween {
			combined(tweens)
		}

		public static func combined(
			from: [UIViewTransition.TransitionClosure],
			to: [UIViewTransition.TransitionClosure]
		) -> Tween {
			Tween(
				from: { view, identity in
					from.reduce(identity) { state, closure in
						state.merged(with: closure(view, state))
					}
				},
				to: { view, identity in
					to.reduce(identity) { state, closure in
						state.merged(with: closure(view, state))
					}
				}
			)
		}
	
		public static func combined(_ tweens: [Tween]) -> Tween {
			Tween(
				from: { view, identity in
					tweens.reduce(identity) { state, tween in
						state.merged(with: tween.from(view, state))
					}
				},
				to: { view, identity in
					tweens.reduce(identity) { state, tween in
						state.merged(with: tween.to(view, state))
					}
				}
			)
		}
		
		public func only(_ keyPath: KeyPath<Self, UIViewTransition.TransitionClosure>) -> UIViewTransition.Tween {
			switch keyPath {
			case \.from:
				return UIViewTransition.Tween(
					from: from,
					to: { _, identity in identity }
				)
			case \.to:
				return UIViewTransition.Tween(
					from: { _, identity in identity },
					to: to
				)
			default:
				return self
			}
		}
	}

	public func tween(for direction: TransitionDirection) -> Tween {
		switch direction {
		case .insertion:
			return Tween(from: willAppear, to: idle)
		case .removal:
			return Tween(from: idle, to: didDisappear)
		}
	}
}

public extension UIViewTransition {

	/// A transition that moves the view in from the specified edge on appearance.
	/// - Parameters:
	///   - edge: The edge from which the view enters.
	///   - offset: The distance to move, relative to the view's size. Defaults to `.relative(1)` (full width/height).
	static func move(from edge: Edge, _ offset: RelationValue<CGFloat> = .relative(1)) -> UIViewTransition {
		UIViewTransition(removed: { view, identity in
			identity.transformed(\.transform) { transform in
				let (dx, dy) = Self.moveOffset(for: edge, view: view, offset: offset)
				return transform.translatedBy(x: dx, y: dy)
			}
		})
	}

	static func move(
		from fromEdge: Edge,
		_ fromOffset: RelationValue<CGFloat> = .relative(1),
		to toEdge: Edge,
		_ toOffset: RelationValue<CGFloat> = .relative(1)
	) -> UIViewTransition {
		UIViewTransition { view, identity in
			identity.transformed(\.transform) { transform in
				let (dx, dy) = Self.moveOffset(for: toEdge, view: view, offset: toOffset)
				return transform.translatedBy(x: dx, y: dy)
			}
		} removed: { view, identity in
			identity.transformed(\.transform) { transform in
				let (dx, dy) = Self.moveOffset(for: fromEdge, view: view, offset: fromOffset)
				return transform.translatedBy(x: dx, y: dy)
			}
		}
	}

	/// A transition that moves the view out towards the specified edge on disappearance.
	/// - Parameters:
	///   - edge: The edge towards which the view exits.
	///   - offset: The distance to move, relative to the view's size. Defaults to `.relative(1)` (full width/height).
	static func move(to edge: Edge, _ offset: RelationValue<CGFloat> = .relative(1)) -> UIViewTransition {
		let original = move(from: edge, offset)
		return UIViewTransition(
			willAppear: original.idle,
			idle: original.willAppear,
			didDisappear: original.idle
		)
	}

	/// Computes the (dx, dy) translation for a move transition, accounting for LTR/RTL layout direction.
	private static func moveOffset(
		for edge: Edge,
		view: UIView,
		offset: RelationValue<CGFloat>
	) -> (CGFloat, CGFloat) {
		let isLtr = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .leftToRight
		switch edge {
		case .leading:
			let value = offset.value(for: view.bounds.width)
			return (isLtr ? -value : value, 0)
		case .trailing:
			let value = offset.value(for: view.bounds.width)
			return (isLtr ? value : -value, 0)
		case .top:
			return (0, -offset.value(for: view.bounds.height))
		case .bottom:
			return (0, offset.value(for: view.bounds.height))
		}
	}

	/// A transition that scales the view from the given scale on appearance.
	/// - Parameters:
	///   - scale: The scale to transition from. Defaults to `0.0001`.
	///   - anchor: The anchor point for scaling. Defaults to `.center`.
	static func scale(from scale: CGFloat = 0.0001, anchor: UnitPoint = .center) -> UIViewTransition {
		UIViewTransition(removed: { view, identity in
			Self.scaledState(identity: identity, scale: scale, anchor: anchor, bounds: view.bounds)
		})
	}

	/// A transition that scales the view to the given scale on disappearance.
	/// - Parameters:
	///   - scale: The scale to transition to. Defaults to `0.0001`.
	///   - anchor: The anchor point for scaling. Defaults to `.center`.
	static func scale(to scale: CGFloat = 0.0001, anchor: UnitPoint = .center) -> UIViewTransition {
		let original = Self.scale(from: scale, anchor: anchor)
		return UIViewTransition(
			willAppear: original.idle,
			idle: original.willAppear,
			didDisappear: original.idle
		)
	}

	/// Computes the scaled UIViewState, compensating for a non-center anchor point via translation.
	private static func scaledState(
		identity: UIViewState,
		scale: CGFloat,
		anchor: UnitPoint,
		bounds: CGRect
	) -> UIViewState {
		let s = scale != 0 ? scale : 0.0001
		// Offset from default center anchor (0.5, 0.5) to the desired anchor, then compensate for scale.
		let dx = (anchor.x - 0.5) * bounds.width * (1 - s)
		let dy = (anchor.y - 0.5) * bounds.height * (1 - s)
		return identity.transformed(\.transform) { transform in
			transform
				.translatedBy(x: dx, y: dy)
				.scaledBy(x: s, y: s)
		}
	}

	/// A transition that changes the background color in the idle state.
	/// - Parameter color: The target background color.
	static func backgroundColor(_ color: UIColor, default initial: UIColor? = nil) -> UIViewTransition {
		.to(\.backgroundColor, color, default: initial)
	}

	static func constant<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: T) -> UIViewTransition {
		UIViewTransition { _, identity in
			identity.with(keyPath, value)
		} removed: { _, identity in
			identity.with(keyPath, value)
		}
	}

	static func tween<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, from: T, to: T) -> UIViewTransition {
		UIViewTransition { _, identity in
			identity.with(keyPath, to)
		} removed: { _, identity in
			identity.with(keyPath, from)
		}
	}

	static func to<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: T, default initial: T? = nil) -> UIViewTransition {
		UIViewTransition { _, identity in
			identity.with(keyPath, value)
		} removed: { _, identity in
			if let initial, !identity.contains(keyPath) {
				return identity.with(keyPath, initial)
			} else {
				return identity
			}
		}
	}

	static func from<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: T, default initial: T? = nil) -> UIViewTransition {
		let result = to(keyPath, value, default: initial)
		return UIViewTransition(
			willAppear: result.idle,
			idle: result.willAppear,
			didDisappear: result.idle
		)
	}

	/// Combines multiple transitions into one by merging their states.
	static func combined(_ transitions: UIViewTransition...) -> UIViewTransition {
		.combined(transitions)
	}

	/// Combines an array of transitions into one by merging their states.
	static func combined(_ transitions: [UIViewTransition]) -> UIViewTransition {
		UIViewTransition(
			willAppear: { view, identity in
				transitions.reduce(identity) { state, transition in
					state.merged(with: transition.willAppear(view, state))
				}
			},
			idle: { view, identity in
				transitions.reduce(identity) { state, transition in
					state.merged(with: transition.idle(view, state))
				}
			},
			didDisappear: { view, identity in
				transitions.reduce(identity) { state, transition in
					state.merged(with: transition.didDisappear(view, state))
				}
			}
		)
	}
}

@dynamicMemberLookup
public struct UIViewState {

	private var values: [Key: Any] = [:]

	public init() {}

	public var allKeys: Set<Key> {
		Set(values.keys)
	}
	
	public func contains<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>) -> Bool {
		values.keys.contains(Key(keyPath))
	}

	public subscript(any key: Key) -> Any? {
		get {
			values[key]
		}
		set {
			values[key] = newValue
		}
	}

	public subscript<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>) -> T {
		get {
			if let value = values[Key(keyPath)], let t = value as? T {
				return t
			}
			return Self.identityView[keyPath: keyPath]
		}
		set {
			values[Key(keyPath)] = newValue
		}
	}

	public subscript<T>(dynamicMember keyPath: ReferenceWritableKeyPath<UIView, T>) -> T {
		get {
			self[keyPath]
		}
		set {
			self[keyPath] = newValue
		}
	}

	public func transformed<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: (T) -> T) -> UIViewState {
		var result = self
		result.values[Key(keyPath)] = value(self[keyPath])
		return result
	}

	public func with<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: T) -> UIViewState {
		var result = self
		result.values[Key(keyPath)] = value
		return result
	}

	public func without<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>) -> UIViewState {
		var result = self
		result.values.removeValue(forKey: Key(keyPath))
		return result
	}

	public var identity: UIViewState {
		var result = self
		for key in allKeys {
			result.values[key] = Self.identityView[keyPath: key.keyPath]
		}
		return result
	}

	public func merged(with other: UIViewState) -> UIViewState {
		var result = self
		result.values.merge(other.values) { _, new in new }
		return result
	}

	public func apply(to view: UIView) {
		for (keyPath, value) in values {
			keyPath.setter(view, value)
		}
	}

	/// Captures the current values of the specified key paths from the view.
	/// - Note: This does not capture any keys that are not explicitly listed in the transition's key paths, so it won't capture all of the view's properties.
	public mutating func snapshot(_ view: UIView) {
		for key in allKeys {
			values[key] = view[keyPath: key.keyPath]
		}
	}

	public struct Key: Hashable, CustomStringConvertible {

		let keyPath: PartialKeyPath<UIView>
		let setter: (UIView, Any) -> Void
		
		public var description: String {
			"\(keyPath)"
		}

		public init<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>) {
			self.keyPath = keyPath
			setter = { view, value in
				if let value = value as? T {
					view[keyPath: keyPath] = value
				}
			}
		}

		public func hash(into hasher: inout Hasher) {
			hasher.combine(keyPath)
		}

		public static func == (lhs: Key, rhs: Key) -> Bool {
			lhs.keyPath == rhs.keyPath
		}
	}

	private static let identityView = UIView()
}

struct AnyEquatable: Equatable {

	let base: Any
	private let compare: (Any, Any) -> Bool

	init<T: Equatable>(_ base: T) {
		self.base = base
		compare = { first, second -> Bool in
			guard let left = first as? T, let right = second as? T else { return false }
			return left == right
		}
	}

	static func == (_ lhs: AnyEquatable, _ rhs: AnyEquatable) -> Bool {
		lhs.compare(lhs.base, rhs.base)
	}
}

private final class PreviewController: UIViewController {
	
	let moving = UIView()

	override func viewDidLoad() {
		super.viewDidLoad()
		
		let container = UIView()
		container.layer.borderColor = UIColor.black.cgColor
		container.layer.borderWidth = 1
		container.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(container)
		NSLayoutConstraint.activate([
			container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
			container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.25),
			container.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.25),
		])
		
		moving.backgroundColor = .systemGreen
		container.addSubview(moving)
		moving.pinEdges(to: container)
		
		let button = UIButton()
		button.setTitle("Move", for: .normal)
		button.setTitleColor(.white, for: .normal)
		button.backgroundColor = .systemBlue
		button.layer.cornerRadius = 20
		button.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(button)
		NSLayoutConstraint.activate([
			button.heightAnchor.constraint(equalToConstant: 70),
			button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
		])
		
		button.addTarget(self, action: #selector(tap), for: .touchUpInside)
	}
	
	@objc
	func tap() {
		let transition = UIViewTransition.move(from: .trailing, to: .leading, .relative(0.3))
		transition.willAppear(moving, UIViewState()).apply(to: moving)
		UIView.animate(withDuration: 0.5, delay: 0) { [self] in
			transition.idle(moving, UIViewState()).apply(to: moving)
		} completion: { [self] _ in
			UIView.animate(withDuration: 0.5, delay: 0) { [self] in
				transition.didDisappear(moving, UIViewState()).apply(to: moving)
			}
		}
	}
}

@available(iOS 17.0, *)
#Preview {
	PreviewController()
}
