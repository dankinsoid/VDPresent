import SwiftUI
import VDTransition

public extension UIPresentation {

	static var navigation: UIPresentation {
		.navigation()
	}

	static func navigation(
		from edge: Edge = .trailing,
		containerColor: UIColor = .black.withAlphaComponent(0.1)
	) -> UIPresentation {
		UIPresentation(
			transition: .base(transitionID: "navigation")
				.environment(\.contentTransition) { _ in .move(from: edge) }
				.environment(\.recessTransition) { _, _ in .move(to: edge.opposite, offset: .relative(0.3)) }
				.environment(\.backEffectBarrier, true)
				.withBackground(containerColor),
			interactivity: .swipe(to: edge),
			animation: .default
		)
		.environment(
			\.backgroundTransition,
			.backgroundColor(containerColor, default: containerColor.withAlphaComponent(0))
		)
	}
}
