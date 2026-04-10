import SwiftUI
import VDTransition

public extension UIPresentation {

	static var sheet: UIPresentation {
		.sheet()
	}

	static func sheet(
		from edge: Edge = .bottom,
		minOffset: CGFloat = 10,
		cornerRadius: CGFloat = 20,
		containerColor: UIColor = .black.withAlphaComponent(0.1)
	) -> UIPresentation {
		UIPresentation(
			transition: .base(transitionID: "sheet")
				.environment(\.contentTransition) { ctx in
					.combined(
						.move(from: edge, relativeTo: { [weak cnt = ctx.container] _ in cnt }),
						.constant(\.clipsToBounds, true),
						.constant(\.layer.cornerRadius, cornerRadius),
						.constant(\.layer.maskedCorners, .edge(edge.opposite))
					)
				}
				.environment(\.contentLayout, .constraints { view, superview in
					var result = view.pinEdges(
						NSDirectionalRectEdge(Edge.allCases.filter { $0 != edge.opposite }),
						to: superview
					)
					result += view.pinEdges(
						NSDirectionalRectEdge(edge.opposite),
						to: superview.safeAreaLayoutGuide,
						relation: .greaterThanOrEqual
					)
					result += view.pinEdges(
						NSDirectionalRectEdge(edge.opposite),
						to: superview.safeAreaLayoutGuide,
						priority: .defaultLow
					)
					return result
				})
				.environment(\.overCurrentContext, true)
				.withBackground(containerColor),
			interactivity: .swipe(to: edge, overscroll: .stretch()),
			animation: .default
		)
	}
}
