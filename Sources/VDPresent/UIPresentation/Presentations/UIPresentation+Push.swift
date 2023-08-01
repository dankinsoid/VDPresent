import SwiftUI
import VDTransition

public extension UIPresentation {
    
    static var push: UIPresentation {
        .push()
    }
    
    static func push(
        to edge: Edge = .trailing,
        containerColor: UIColor = .black.withAlphaComponent(0.1)
    ) -> UIPresentation {
        UIPresentation(
            transition: .default(
                transition: .move(edge: edge),
                moveToBackTransition: .move(edge: edge.opposite, offset: .relative(0.3)),
                overCurrentContext: false
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
