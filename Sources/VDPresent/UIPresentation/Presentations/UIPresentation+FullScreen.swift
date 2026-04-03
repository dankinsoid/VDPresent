import SwiftUI
import VDTransition

public extension UIPresentation {

	static var fullScreen: UIPresentation {
		.fullScreen(from: .bottom)
	}

	static var overFullScreen: UIPresentation {
		.fullScreen(from: .bottom, overCurrentContext: true)
	}

	static func fullScreen(
		from edge: Edge,
		containerColor: UIColor = .black.withAlphaComponent(0.1),
		interactive: Bool = false,
		overCurrentContext: Bool = false
	) -> UIPresentation {
		.fullScreen(
			.move(from: edge),
			interactivity: interactive ? .swipe(to: edge) : nil
		)
		.environment(
			\.backgroundTransition,
			containerColor == .clear
				? .identity
			  : .tween(\.backgroundColor, from: containerColor.withAlphaComponent(0), to: containerColor)
		)
	}

	static func fullScreen(
		_ transition: UIViewTransition,
		interactivity: UIPresentation.Interactivity? = nil,
		overCurrentContext: Bool = false
	) -> UIPresentation {
		UIPresentation(
			transition: .base(transitionID: "fullScreen")
				.environment(\.contentTransition) { _ in transition }
				.environment(\.overCurrentContext, overCurrentContext)
				.withBackground(.identity),
			interactivity: interactivity,
			animation: .default
		)
	}
}
