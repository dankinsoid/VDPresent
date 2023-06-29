import SwiftUI

public extension UIPresentation {

	static var sheet: UIPresentation {
		.sheet()
	}
    
    static var pageSheet: UIPresentation {
        .sheet(selfSized: false)
    }

	static func sheet(
		from edge: Edge = .bottom,
		minOffset: CGFloat = 10,
        selfSized: Bool = true,
		cornerRadius: CGFloat = 10,
		containerColor: UIColor = .pageSheetBackground,
		onBouncing: @escaping (CGFloat) -> Void = { _ in }
	) -> UIPresentation {
		UIPresentation(
			transition: .sheet(
				from: edge,
				minOffset: minOffset,
                selfSized: selfSized,
				cornerRadius: cornerRadius,
				containerColor: containerColor,
				onBouncing: onBouncing
			),
			interactivity: .swipe(to: edge),
			animation: .default
		)
	}
}

public extension UIPresentation.Transition {

	static var sheet: UIPresentation.Transition {
		.sheet()
	}

	static func sheet(
		from edge: Edge = .bottom,
		minOffset: CGFloat = 10,
        selfSized: Bool = true,
		cornerRadius: CGFloat = 10,
		containerColor: UIColor = .pageSheetBackground,
		onBouncing: @escaping (CGFloat) -> Void = { _ in }
	) -> UIPresentation.Transition {
        let paddingLayout = ContentLayout.padding(
            NSDirectionalEdgeInsets([edge.opposite: minOffset]),
            insideSafeArea: NSDirectionalRectEdge(edge.opposite)
        )
		return UIPresentation.Transition(
			content: .asymmetric(
                insertion: .move(edge: edge),
				removal: .scale(0.98)
			),
            layout: selfSized ? paddingLayout.combine(.alignment(.edge(edge))) : paddingLayout,
			background: .backgroundColor(containerColor),
			applyTransitionOnBothControllers: true
        ) { context in
            context.viewControllersToInsert.forEach {
                let view = context.view(for: $0)
                view.clipsToBounds = true
                view.layer.cornerRadius = cornerRadius
                view.layer.maskedCorners = .edge(edge.opposite)
            }
        } completion: { _, _ in
        }
	}
}

public extension UIColor {

	static var pageSheetBackground: UIColor {
		UIColor(displayP3Red: 0.21, green: 0.21, blue: 0.23, alpha: 0.37)
	}
}
