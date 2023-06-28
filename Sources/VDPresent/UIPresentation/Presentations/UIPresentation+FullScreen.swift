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
			interactivity: interactive ? .swipe(to: NSDirectionalRectEdge(edge)) : nil,
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
            background: containerColor == .clear
                ? .identity
                : .value(\.backgroundColor, containerColor, default: containerColor.withAlphaComponent(0)),
			applyTransitionOnBothControllers: false
		) { context in
			for viewController in context.toViewControllers {
                context.container(for: viewController)
                    .addSubview(
                        context.view(for: viewController),
                        alignment: .edges()
                    )
			}
		} completion: { _, _ in
		}
	}
    
    static var fade: UIPresentation.Transition {
        UIPresentation.Transition(
            content: .opacity,
            background: .identity,
            applyTransitionOnBothControllers: false
        ) { context in
            for viewController in context.toViewControllers {
                context.container(for: viewController)
                    .addSubview(
                        context.view(for: viewController),
                        alignment: .edges()
                    )
            }
        } completion: { _, _ in
        }
    }
}
