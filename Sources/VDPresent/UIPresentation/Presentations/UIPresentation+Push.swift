import SwiftUI
import VDTransition

public extension UIPresentation {
    
    static var push: UIPresentation {
        .push()
    }
    
    static func push(
        to edge: Edge = .trailing,
        containerColor: UIColor = .black.withAlphaComponent(0.1),
        backViewControllerOffset offset: RelationValue<CGFloat> = .relative(0.7)
    ) -> UIPresentation {
        UIPresentation(
            transition: .push(
                to: edge,
                containerColor: containerColor,
                backViewControllerOffset: offset
            ),
            interactivity: .swipe(to: edge),
            animation: .default(UINavigationController.hideShowBarDuration)
        )
    }
}

public extension UIPresentation.Transition {
    
    static func push(
        to edge: Edge = .trailing,
        containerColor: UIColor = .black.withAlphaComponent(0.1),
        backViewControllerOffset offset: RelationValue<CGFloat> = .relative(0.7)
    ) -> UIPresentation.Transition {
        UIPresentation.Transition(
            content: .asymmetric(
                insertion: .move(edge: edge),
                removal: .move(edge: edge.opposite, offset: offset)
            ),
            layout: .fill,
            background: .value(\.backgroundColor, containerColor, default: containerColor.withAlphaComponent(0)),
            applyTransitionOnBackControllers: true,
            animateBackControllersReorder: false
        )
    }
}
