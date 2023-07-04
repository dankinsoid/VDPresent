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
        let paddingLayout = ContentLayout.padding(
            NSDirectionalEdgeInsets([edge.opposite: minOffset]),
            insideSafeArea: NSDirectionalRectEdge(edge.opposite)
        )
		return UIPresentation(
            transition: .default(
                transition: .asymmetric(
                    insertion: [
                        .move(edge: edge),
                        .constant(\.clipsToBounds, true),
                        .constant(\.layer.cornerRadius, cornerRadius),
                        .constant(\.layer.maskedCorners, .edge(edge.opposite))
                    ],
                    removal: [.scale(0.9)]
                ),
                layout: selfSized ? paddingLayout.combine(.alignment(.edge(edge))) : paddingLayout,
                applyTransitionOnBackControllers: true,
                contextTransparencyDeep: selfSized ? nil : 1
            )
            .withBackground(containerColor).environment(\.isOverlay, !selfSized),
			interactivity: .swipe(to: edge),
			animation: .default
		)
	}
}

public extension UIColor {

	static var pageSheetBackground: UIColor {
		UIColor(displayP3Red: 0.21, green: 0.21, blue: 0.23, alpha: 0.37)
	}
}
