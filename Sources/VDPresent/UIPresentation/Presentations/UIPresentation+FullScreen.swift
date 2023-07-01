import SwiftUI
import VDTransition

public extension UIPresentation {

	static var fullScreen: UIPresentation {
		.fullScreen()
	}
    
    static var overFullScreen: UIPresentation {
        .fullScreen(overCurrentContext: true)
    }
    
	static func fullScreen(
		from edge: Edge = .bottom,
		containerColor: UIColor = .pageSheetBackground,
		interactive: Bool = false,
        overCurrentContext: Bool = false
	) -> UIPresentation {
		UIPresentation(
            transition: .default(),
			interactivity: interactive ? .swipe(to: edge) : nil,
			animation: .default
		)
        .environment(\.contentTransition, .move(edge: edge))
        .environment(\.contentLayout, .fill)
        .environment(
            \.backgroundTransition,
             containerColor == .clear
                ? .identity
                : .value(\.backgroundColor, containerColor, default: containerColor.withAlphaComponent(0))
        )
        .environment(\.applyTransitionOnBackControllers, false)
        .environment(\.animateBackControllersReorder, false)
        .environment(\.hideBackControllers, !overCurrentContext)
	}
    
    static var fade: UIPresentation {
        UIPresentation(
            transition: .default(),
            interactivity: nil,
            animation: .default
        )
        .environment(\.contentTransition, .opacity)
        .environment(\.contentLayout, .fill)
        .environment(\.applyTransitionOnBackControllers, false)
        .environment(\.animateBackControllersReorder, false)
        .environment(\.hideBackControllers, true)
    }
}
