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
			background: .backgroundColor(containerColor),
			applyTransitionOnBothControllers: false
		) { context in
			for viewController in context.toViewControllers {
				context.container.addSubview(viewController.view)
				if context.constraints[viewController.view] == nil {
					context.constraints[viewController.view] = viewController.view.pinEdges(
						to: viewController.view.superview ?? context.container
					)
				}
			}
		} completion: { context, isCompleted in
			if isCompleted {
				context.viewControllersToRemove.forEach {
					$0.view.removeFromSuperview()
					context.constraints[$0.view] = nil
				}
			} else {
				context.viewControllersToInsert.forEach {
					$0.view.removeFromSuperview()
					context.constraints[$0.view] = nil
				}
			}
		}
	}
}
