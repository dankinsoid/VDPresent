import SwiftUI
import VDTransition

public extension UIPresentation {
    
    static var pageSheet: UIPresentation {
        .pageSheet()
    }
    
    static func pageSheet(
        from edge: Edge = .bottom,
        minOffset: CGFloat = 10,
        cornerRadius: CGFloat = 10,
        containerColor: UIColor = .pageSheetBackground
    ) -> UIPresentation {
        UIPresentation(
            transition: .default(
                layout: .padding(
                    NSDirectionalEdgeInsets(
                        [
                            edge.opposite: edge == .leading || edge == .trailing
                                ? minOffset + UIScreen.main.displayCornerRadius / 2
                                : minOffset
                        ]
                    ),
                    insideSafeArea: NSDirectionalRectEdge(edge.opposite)
                )
            )
            .environment(\.contentTransition) { context in
                [
                    .move(edge: edge),
                    .constant(\.clipsToBounds, true),
                    .constant(\.layer.cornerRadius, cornerRadius),
                    .constant(\.layer.maskedCorners, .edge(edge.opposite))
                ]
            }
            .environment(\.moveToBackTransition) { i, context in
                .transform(
                    to: context.view,
                    edge: edge.opposite,
                    cornerRadius: cornerRadius,
                    up: i == 1
                )
            }
            .environment(\.overCurrentContext) { context in
                context.viewControllers.to.last === context.viewController || context.isTopController
            }
            .withBackground(containerColor)
            .environment(\.isOverlay, true),
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

private extension UITransition<UIView> {
    
    static func transform(
        to targetView: UIView,
        edge: Edge,
        cornerRadius: CGFloat,
        up: Bool
    ) -> UITransition {
        UITransition(PageSheetModifier(targetView)) { progress, view, initial in
            view.affineTransform = UITransition<UIView>.transform(
                progress: progress,
                initial: initial,
                edge: edge,
                cornerRadius: cornerRadius,
                isLtr: view.isLtrDirection,
                up: up
            )
            view.clipsToBounds = true
            view.layer.maskedCorners = .edge(edge)
            view.layer.cornerRadius = UITransition<UIView>.cornerRadius(
                progress: progress,
                initial: initial,
                edge: edge,
                cornerRadius: cornerRadius,
                isLtr: view.isLtrDirection
            )
        }
    }
    
    static func transform(
        progress: Progress,
        initial: PageSheetModifier.Value,
        edge: Edge,
        cornerRadius: CGFloat,
        isLtr: Bool,
        up: Bool
    ) -> CGAffineTransform {
        let k = cornerRadius * 1.2
        var targetRect = initial.targetRect
        
        switch edge {
        case .top:
            targetRect.origin.x += k
            targetRect.size.width -= k * 2
            targetRect.size.height = targetRect.size.width * (initial.targetRect.height / initial.targetRect.width.notZero)
            if up {
                targetRect.origin.y -= k
            }
            
        case .leading, .trailing:
            targetRect.origin.y += k
            targetRect.size.height -= k * 2
            let newWidth = targetRect.size.height * (initial.targetRect.width / initial.targetRect.height.notZero)
            if isLtr == (edge == .leading) {
                targetRect.origin.x = targetRect.maxX - newWidth
                targetRect.size.width = newWidth
                if up {
                    targetRect.origin.x -= k
                }
            } else {
                targetRect.size.width = newWidth
                if up {
                    targetRect.origin.x += k
                }
            }
            
        case .bottom:
            targetRect.origin.x += k
            targetRect.size.width -= k * 2
            let newHeight = targetRect.size.width * (initial.targetRect.height / initial.targetRect.width.notZero)
            targetRect.origin.y = targetRect.maxY - newHeight
            targetRect.size.height = newHeight
            if up {
                targetRect.origin.y += k
            }
        }
        
        let scale = CGSize(
            width: progress.value(
                identity: 1,
                transformed: targetRect.width / initial.sourceRect.width.notZero
            ),
            height: progress.value(
                identity: 1,
                transformed: targetRect.height / initial.sourceRect.height.notZero
            )
        )
        
        let offset = CGPoint(
            x: progress.value(
                identity: 0,
                transformed: targetRect.midX - initial.sourceRect.midX
            ),
            y: progress.value(
                identity: 0,
                transformed: targetRect.midY - initial.sourceRect.midY
            )
        )
        
        return initial.sourceTransform
            .translatedBy(x: offset.x, y: offset.y)
            .scaledBy(x: scale.width, y: scale.height)
    }
    
    static func cornerRadius(
        progress: Progress,
        initial: PageSheetModifier.Value,
        edge: Edge,
        cornerRadius: CGFloat,
        isLtr: Bool
    ) -> CGFloat {
        let displayRadius = UIScreen.main.displayCornerRadius
        let initialRadius: CGFloat
        switch edge {
        case .top:
            initialRadius = initial.sourceRect.minY == 0
            ? displayRadius
            : cornerRadius
        case .leading, .trailing:
            if isLtr == (edge == .leading) {
                initialRadius = UIScreen.main.bounds.width == initial.sourceRect.maxX
                ? displayRadius
                : cornerRadius
            } else {
                initialRadius = initial.sourceRect.minX == 0
                ? displayRadius
                : cornerRadius
            }
        case .bottom:
            initialRadius = UIScreen.main.bounds.height == initial.sourceRect.maxY
            ? displayRadius
            : cornerRadius
        }
        return progress.value(
            identity: initialRadius,
            transformed: cornerRadius
        )
    }
}

private struct PageSheetModifier: TransitionModifier {
    
    weak var target: UIView?
    
    init(_ target: UIView?) {
        self.target = target
    }
    
    func matches(other: PageSheetModifier) -> Bool {
        other.target === target
    }
    
    func set(value: Value, to root: UIView) {
        root.affineTransform = value.sourceTransform
        root.layer.cornerRadius = value.cornerRadius
        root.layer.maskedCorners = value.cornerMask
        root.clipsToBounds = value.clipsToBounds
    }
    
    func value(for root: UIView) -> Value {
        Value(
            sourceTransform: root.affineTransform,
            cornerRadius: root.layer.cornerRadius,
            cornerMask: root.layer.maskedCorners,
            clipsToBounds: root.clipsToBounds,
            sourceRect: root.convert(root.bounds, to: nil),
            targetRect: target?.convert(target?.bounds ?? .zero, to: nil) ?? root.bounds
        )
    }
    
    struct Value {
        
        var sourceTransform: CGAffineTransform
        var cornerRadius: CGFloat
        var cornerMask: CACornerMask
        var clipsToBounds: Bool
        var sourceRect: CGRect
        var targetRect: CGRect
    }
}
