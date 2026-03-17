import UIKit
import VDTransition

extension UIPresentation.Transition {

	func withBackground(
		_ color: UIColor,
		layout: ContentLayout = .fill
	) -> UIPresentation.Transition {
		withBackground(
			color == .clear
				? .identity
				: .backgroundColor(color, default: color.withAlphaComponent(0)),
			layout: layout
		)
	}

	func withBackground(
		_ transition: UIViewTransition,
		layout: ContentLayout = .fill
	) -> UIPresentation.Transition {
		environment(\.backgroundTransition, transition)
			.environment(\.backgroundLayout, layout)
			.environment(\.backgroundPlacement, .global)
	}

	func withOverlay(
		_ color: UIColor
	) -> UIPresentation.Transition {
		withBackground(color).environment(\.backgroundPlacement, .behindController)
	}

	func withOverlay(
		_ transition: UIViewTransition
	) -> UIPresentation.Transition {
		withBackground(transition).environment(\.backgroundPlacement, .behindController)
	}
}

public extension UIPresentation.Environment {

	var backgroundLayout: ContentLayout {
		get { self[\.backgroundLayout] ?? .fill }
		set { self[\.backgroundLayout] = newValue }
	}

	var backgroundTransition: UITransition<UIView> {
		get { self[\.backgroundTransition] ?? .identity }
		set { self[\.backgroundTransition] = newValue }
	}
}

/// Where the background/overlay view is placed in the view hierarchy.
public enum BackgroundPlacement {

	/// Background is added to this controller's own canvas (covers the full screen).
	case global

	/// Background is added as a subview of the controller directly behind this one.
	case behindController
}

extension UIPresentation.Environment {

	var backgroundPlacement: BackgroundPlacement {
		get { self[\.backgroundPlacement] ?? .global }
		set { self[\.backgroundPlacement] = newValue }
	}
}

extension UIPresentation.Context {

	var backgroundTransitions: [Weak<UIView>: UITransition<UIView>] {
		get {
			cache[\.backgroundTransitions] ?? [:]
		}
		nonmutating set {
			cache[\.backgroundTransitions] = newValue
		}
	}

	var backgroundView: UIView? {
		get { backgroundViews[view]?.value }
		nonmutating set {
			if let newValue {
				backgroundViews[view] = Weak(newValue)
			} else {
				backgroundViews[view] = nil
			}
		}
	}
}

private extension UIPresentation.Context {

	var backgroundViews: [Weak<UIView>: Weak<UIView>] {
		get { cache[\.backgroundViews] ?? [:] }
		nonmutating set { cache[\.backgroundViews] = newValue }
	}
}
