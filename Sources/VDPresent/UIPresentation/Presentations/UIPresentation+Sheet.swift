import SwiftUI

public extension UIPresentation {

	static var sheet: UIPresentation {
		.sheet()
	}

	static func sheet(
		from edge: Edge = .bottom,
		minOffset: CGFloat = 10,
		cornerRadius: CGFloat = 10,
		containerColor: UIColor = .pageSheetBackground,
		onBouncing: @escaping (CGFloat) -> Void = { _ in }
	) -> UIPresentation {
		UIPresentation(
			transition: .sheet(
				from: edge,
				minOffset: minOffset,
				cornerRadius: cornerRadius,
				containerColor: containerColor,
				onBouncing: onBouncing
			),
			interactivity: .swipe(to: NSDirectionalRectEdge(edge)),
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
		cornerRadius: CGFloat = 10,
		containerColor: UIColor = .pageSheetBackground,
		onBouncing: @escaping (CGFloat) -> Void = { _ in }
	) -> UIPresentation.Transition {
		UIPresentation.Transition(
			content: .asymmetric(
				insertion: [
					.move(edge: edge),
					.constant(\.layer.cornerRadius, cornerRadius),
					.constant(\.clipsToBounds, true),
					.constant(\.layer.maskedCorners, .edge(edge.opposite)),
				],
				removal: [
					.constant(\.clipsToBounds, true),
				]
			),
            layout: .alignment(.edge(edge)),
			background: .backgroundColor(containerColor),
			applyTransitionOnBothControllers: false
		)
	}
}

public extension UIColor {

	static var pageSheetBackground: UIColor {
		UIColor(displayP3Red: 0.21, green: 0.21, blue: 0.23, alpha: 0.37)
	}
}
