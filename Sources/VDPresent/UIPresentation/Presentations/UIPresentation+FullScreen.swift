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
        containerColor: UIColor = .pageSheetBackground,
        interactive: Bool = false,
        overCurrentContext: Bool = false
    ) -> UIPresentation {
        .fullScreen(
            .move(edge: edge),
            interactivity: interactive ? .swipe(to: edge) : nil
        )
        .environment(
            \.backgroundTransition,
             containerColor == .clear
               ? .identity
               : .value(\.backgroundColor, containerColor, default: containerColor.withAlphaComponent(0))
        )
    }
    
	static func fullScreen(
        _ transition: UIViewTransition,
        interactivity: UIPresentation.Interactivity? = nil,
        overCurrentContext: Bool = false
	) -> UIPresentation {
		UIPresentation(
			interactivity: interactivity,
			animation: .default
		)
        .environment(\.contentTransition, transition)
        .environment(\.contentLayout, .fill)
        .environment(\.applyTransitionOnBackControllers, false)
        .environment(\.animateBackControllersReorder, false)
        .environment(\.hideBackControllers, !overCurrentContext)
	}
}
