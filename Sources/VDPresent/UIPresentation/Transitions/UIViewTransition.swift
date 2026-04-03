import SwiftUI
import UIKit
import VDTransition

public struct UIViewTransition {

	public typealias TransitionClosure = @MainActor (UIView, _ identity: UIViewState) -> UIViewState

	public var willAppear: TransitionClosure
	public var idle: TransitionClosure
	public var didDisappear: TransitionClosure

	public init(
		willAppear: @escaping TransitionClosure,
		idle: @escaping TransitionClosure = { _, identity in identity },
		didDisappear: @escaping TransitionClosure
	) {
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

public extension UIViewTransition {

	/// A transition that moves the view in from the specified edge on appearance.
	/// - Parameters:
	///   - edge: The edge from which the view enters.
	///   - offset: The distance to move, relative to the view's size. Defaults to `.relative(1)` (full width/height).
	static func move(from edge: Edge, offset: RelationValue<CGFloat> = .relative(1)) -> UIViewTransition {
		UIViewTransition(removed: { view, identity in
			identity.transformed(\.transform) { transform in
				let (dx, dy) = Self.moveOffset(for: edge, view: view, offset: offset)
				return transform.translatedBy(x: dx, y: dy)
			}
		})
	}

	/// A transition that moves the view out towards the specified edge on disappearance.
	/// - Parameters:
	///   - edge: The edge towards which the view exits.
	///   - offset: The distance to move, relative to the view's size. Defaults to `.relative(1)` (full width/height).
	static func move(to edge: Edge, offset: RelationValue<CGFloat> = .relative(1)) -> UIViewTransition {
		let original = move(from: edge, offset: offset)
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
			let value = offset.value(for: view.frame.width)
			return (isLtr ? -value : value, 0)
		case .trailing:
			let value = offset.value(for: view.frame.width)
			return (isLtr ? value : -value, 0)
		case .top:
			return (0, -offset.value(for: view.frame.height))
		case .bottom:
			return (0, offset.value(for: view.frame.height))
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

	static func constant<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: T) -> UIViewTransition {
		UIViewTransition { _, identity in
			identity.with(keyPath, value)
		} removed: { _, identity in
			identity.with(keyPath, value)
		}
	}

	static func to<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: T) -> UIViewTransition {
		UIViewTransition { _, identity in
			identity.with(keyPath, value)
		} removed: { _, identity in
			identity
		}
	}

	static func from<T>(_ keyPath: ReferenceWritableKeyPath<UIView, T>, _ value: T) -> UIViewTransition {
		UIViewTransition { _, identity in
			identity
		} removed: { _, identity in
			identity.with(keyPath, value)
		}
	}

	static let identity = UIViewTransition { _, identity in identity }
}

@dynamicMemberLookup
public struct UIViewState {

	private var values: [Key: Any] = [:]

	public init() {}

	public var allKeys: Set<Key> {
		Set(values.keys)
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

	public struct Key: Hashable {

		let keyPath: PartialKeyPath<UIView>
		let setter: (UIView, Any) -> Void

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
