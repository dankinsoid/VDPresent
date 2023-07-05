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
        containerColor: UIColor = .black.withAlphaComponent(0.1),
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
               : .backgroundColor(containerColor, default: containerColor.withAlphaComponent(0))
        )
    }
    
	static func fullScreen(
        _ transition: UIViewTransition,
        interactivity: UIPresentation.Interactivity? = nil,
        overCurrentContext: Bool = false
	) -> UIPresentation {
		UIPresentation(
            transition: .default(
                transition: transition,
                layout: .fill,
                applyTransitionOnBackControllers: false,
                contextTransparencyDeep: overCurrentContext ? nil : 0
            )
            .withBackground(.identity),
			interactivity: interactivity,
			animation: .default
		)
	}
}
