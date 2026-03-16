import SwiftUI
import VDTransition

public extension UIPresentation {
    
    static var push: UIPresentation {
        .push()
    }
    
    static func push(
        from edge: Edge = .trailing,
        containerColor: UIColor = .black.withAlphaComponent(0.1)
    ) -> UIPresentation {
        UIPresentation(
            transition: .base()
            .environment(\.contentTransition) { _ in .move(edge: edge) }
            .environment(\.moveToBackTransition) { _, _ in .move(edge: edge.opposite, offset: .relative(0.3)) }
						.environment(\.backEffectBarrier, "push")
            .withBackground(containerColor),
            interactivity: .swipe(to: edge),
            animation: .default
        )
        .environment(
            \.backgroundTransition,
             .value(\.backgroundColor, containerColor, default: containerColor.withAlphaComponent(0))
        )
        .environment(\.swipeFromEdge, true)
    }
}
