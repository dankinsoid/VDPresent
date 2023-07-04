import SwiftUI
import VDTransition

public extension UIPresentation {
    
    static var push: UIPresentation {
        .push()
    }
    
    static func push(
        to edge: Edge = .trailing,
        containerColor: UIColor = .black.withAlphaComponent(0.1),
        backViewControllerOffset offset: RelationValue<CGFloat> = .relative(0.3)
    ) -> UIPresentation {
        UIPresentation(
            transition: .default(
                transition: .asymmetric(
                    insertion: .move(edge: edge),
                    removal: .move(edge: edge.opposite, offset: offset)
                ),
                applyTransitionOnBackControllers: true,
                contextTransparencyDeep: 0
            )
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
