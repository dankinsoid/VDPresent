import SwiftUI
import VDTransition

public extension UIPresentation {

	static var fullScreen: UIPresentation {
		.fullScreen()
	}
    
	static func fullScreen(
		from edge: Edge = .bottom,
		containerColor: UIColor = .pageSheetBackground,
		interactive: Bool = false
	) -> UIPresentation {
		UIPresentation(
			transition: .fullScreen(
				from: edge,
				containerColor: containerColor
			),
			interactivity: interactive ? .swipe(to: edge) : nil,
			animation: .default
		)
	}
    
    static var fade: UIPresentation {
        UIPresentation(
            transition: .fade,
            interactivity: nil,
            animation: .default
        )
    }
}

public extension UIPresentation.Transition {

	static var fullScreen: UIPresentation.Transition {
		.fullScreen()
	}

	static func fullScreen(
		from edge: Edge = .bottom,
		containerColor: UIColor = .pageSheetBackground
	) -> UIPresentation.Transition {
		UIPresentation.Transition(
			content: .move(edge: edge),
            layout: .fill,
            background: containerColor == .clear
                ? .identity
                : .value(\.backgroundColor, containerColor, default: containerColor.withAlphaComponent(0)),
            applyTransitionOnBackControllers: false,
            animateBackControllersReorder: false
		)
	}
    
    static var fade: UIPresentation.Transition {
        UIPresentation.Transition(
            content: .opacity,
            layout: .fill,
            background: .identity,
            applyTransitionOnBackControllers: false,
            animateBackControllersReorder: false
        )
    }
}
