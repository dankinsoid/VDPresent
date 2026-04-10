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
				.environment(\.contentTransition) { ctx in
						.move(from: edge, relativeTo: { [weak cnt = ctx.container] _ in cnt })
				}
				.environment(\.recessTransition) { _, ctx in
					.move(from: edge, to: edge.opposite, .relative(0.3), relativeTo: { [weak cnt = ctx.container] _ in cnt })
				}
				.environment(\.backEffectBarrier, true)
				.withBackground(containerColor),
			interactivity: .swipe(to: edge),
			animation: .default
		)
		.environment(
			\.backgroundTransition,
			.tween(\.backgroundColor, from: containerColor.withAlphaComponent(0), to: containerColor)
		)
	}
}
