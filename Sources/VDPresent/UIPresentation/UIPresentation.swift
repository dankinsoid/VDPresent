import UIKit
@_exported import VDTransition

public typealias Progress = VDTransition.Progress

public struct UIPresentation {

	public var transition: Transition
	public var interactivity: Interactivity?
	public var animation: UIKitAnimation
	public var environment: Environment { transition.environment }

	public init(
		transition: Transition,
		interactivity: Interactivity? = nil,
		animation: UIKitAnimation = .default
	) {
		self.transition = transition
		self.interactivity = interactivity
		self.animation = animation
	}

	public static var `default` = UIPresentation.sheet

	public var nonInteractive: UIPresentation {
		var result = self
		result.interactivity = nil
		return result
	}

	public func with(animation: UIKitAnimation) -> UIPresentation {
		var result = self
		result.animation = animation
		return result
	}

	public func with(interactivity: Interactivity?) -> UIPresentation {
		var result = self
		result.interactivity = interactivity
		return result
	}

	public func environment<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>, _ value: T) -> UIPresentation {
		var result = self
		result.transition = transition.environment(keyPath, value)
		return result
	}

	public func transformEnvironment<T>(
		_ keyPath: WritableKeyPath<UIPresentation.Environment, T>,
		_ value: (T) -> T
	) -> UIPresentation {
		var result = self
		result.transition = transition.transformEnvironment(keyPath, value)
		return result
	}
}

public extension UIPresentation {

	struct Interactivity {

		private let installer: (Context, @escaping (Context, State) -> Policy) -> Void
		private let uninstaller: (Context) -> Void

		public init(
			installer: @escaping (Context, @escaping (Context, State) -> Policy) -> Void,
			uninstaller: @escaping (Context) -> Void
		) {
			self.installer = installer
			self.uninstaller = uninstaller
		}

		public func install(context: Context, observer: @escaping (Context, State) -> Policy) {
			installer(context, observer)
		}

		public func uninstall(context: Context) {
			uninstaller(context)
		}

		public enum Policy {
			case allow, prevent
		}

		public enum State: Equatable {

			case begin
			case change(Progress)
			case end(completed: Bool, after: Double)
		}
	}

	/// Describes the visual changes for a single view controller transition.
	///
	/// `Transition` is a pure data object — it declares *what* to animate, not *how*.
	/// The animation driver (UIView.animate, UIViewPropertyAnimator, CAAnimation, …)
	/// is chosen externally by whoever runs the transition (typically `UIStackController`).
	///
	/// - `prepare`: called before the animation block to set initial state.
	/// - `animation`: called inside the animation block (or at each progress tick).
	/// - `completion`: called after the animation finishes; `Bool` is `true` when completed.
	struct Transition {

		public static var identity: UIPresentation.Transition {
			UIPresentation.Transition(transitionID: "identity")
		}

		/// Identifies the type of transition (e.g. "push", "fullScreen", "sheet").
		/// Used by `behindBehavior(.freezeMatching)` to decide which behind-controllers
		/// are frozen vs animated during stack changes.
		public var transitionID: AnyHashable

		/// Sets up initial state before animation begins (layout, transforms, visibility).
		public var prepare: (Context) -> Void

		/// The animatable changes — called inside an animation block or at each progress step.
		public var animation: (Context) -> Void

		/// Called after the animation finishes. `Bool` is `false` when cancelled.
		public var completion: (Context, Bool) -> Void

		public var environment: UIPresentation.Environment

		public init(
			transitionID: AnyHashable,
			environment: UIPresentation.Environment = UIPresentation.Environment(),
			prepare: @escaping (Context) -> Void = { _ in },
			animation: @escaping (Context) -> Void = { _ in },
			completion: @escaping (Context, Bool) -> Void = { _, _ in }
		) {
			self.transitionID = transitionID
			self.prepare = prepare
			self.animation = animation
			self.completion = completion
			self.environment = environment
		}

		public func environment<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>, _ value: T) -> UIPresentation.Transition {
			var result = self
			result.environment[keyPath: keyPath] = value
			return result
		}

		public func transformEnvironment<T>(
			_ keyPath: WritableKeyPath<UIPresentation.Environment, T>,
			_ value: (T) -> T
		) -> UIPresentation.Transition {
			var result = self
			result.environment[keyPath: keyPath] = value(result.environment[keyPath: keyPath])
			return result
		}
	}
}

public extension UIPresentation {

	struct Environment {

		private var values: [PartialKeyPath<UIPresentation.Environment>: Any] = [:]

		public subscript<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>) -> T? {
			get { values[keyPath] as? T }
			set { values[keyPath] = newValue }
		}

		public init() {}

		public func with<T>(_ keyPath: WritableKeyPath<UIPresentation.Environment, T>, _ value: T?) -> UIPresentation.Environment {
			var result = self
			result[keyPath] = value
			return result
		}
	}
}
