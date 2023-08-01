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
            transition: .default(
                transition: [
                    .move(edge: edge),
                    .constant(\.clipsToBounds, true),
                    .constant(\.layer.cornerRadius, cornerRadius),
                    .constant(\.layer.maskedCorners, .edge(edge.opposite))
                ],
                layout: .padding(
                    NSDirectionalEdgeInsets([edge.opposite: minOffset]),
                    insideSafeArea: NSDirectionalRectEdge(edge.opposite)
                )
                .combine(.alignment(.edge(edge))),
                overCurrentContext: true
            )
            .withBackground(containerColor),
			interactivity: .swipe(to: edge),
			animation: .default
		)
	}
}
