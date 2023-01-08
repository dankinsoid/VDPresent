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
                    .constant(\.layer.maskedCorners, .edge(edge.opposite))
                ],
                removal: [
                    .constant(\.clipsToBounds, true)
                ]
            ),
            background: .backgroundColor(containerColor),
            applyTransitionOnBothControllers: true
        ) { context in
            guard context.direction == .insertion else { return }
            
            let toViewControllers = context.toViewControllers
            let changingViews: [UIView] = toViewControllers.map(\.view)
            
//            if let superView = changingView.superview {
//                var edges = Edge.allCases
//                if let i = edges.firstIndex(of: edge.opposite) {
//                    edges.remove(at: i)
//                }
//                changingView.pinEdges(NSDirectionalRectEdge(edges), to: superView)
//            		changingView.pinEdges(
//                    NSDirectionalRectEdge(edge.opposite),
//                    to: superView.safeAreaLayoutGuide,
//                    padding: minOffset,
//                    priority: .defaultHigh
//                )
//            }
            
            let recognizer = TransitionContainerTapRecognizer()
//            recognizer.onTap = { [weak toViewController] in
//                toViewController?.hide()
//            }
            context.container.addGestureRecognizer(recognizer)
        } completion: { context, isCompleted in
            
        }
//        result.restoreDisappearedViews = false
//
//        let insets = (UIWindow.key?.safeAreaInsets ?? .zero)[edge.opposite]
//        let offset = insets + minOffset
//        let dif = offset - insets
//
//        var constraint: NSLayoutConstraint?
//
//        result.onContainerTap = { [weak result] in
//            guard result?.owner?.isModalInPresentation != true else { return }
//            result?.owner?.dismiss(animated: true, completion: nil)
//        }
//
//        var previousKoeficient: CGFloat = 0
//        result.interactivity.disappear = .swipe(to: UIRectEdge(edge)) {
//            .dismiss(delegate: $0)
//        } observe: {
//            let koeficient = ($0 > 0 ? 0 : 2 * dif * atan(-$0 / dif) / CGFloat.pi)
//            let newOffset = offset - koeficient
//            guard koeficient != previousKoeficient else { return }
//            let constant = (edge == .trailing || edge == .bottom ? 1 : -1) * newOffset
//            if constant != constraint?.constant {
//                constraint?.constant = constant
//            }
//            previousKoeficient = koeficient
//            onBouncing(max(0, -$0))
//        }
//        return result
    }
    
}

public extension UIColor {
    
    static var pageSheetBackground: UIColor {
        UIColor(displayP3Red: 0.21, green: 0.21, blue: 0.23, alpha: 0.37)
    }
}
