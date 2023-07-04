import SwiftUI
import VDTransition

public extension UIPresentation {

	static var sheet: UIPresentation {
		.sheet()
	}
    
    static var pageSheet: UIPresentation {
        .pageSheet()
    }

	static func sheet(
		from edge: Edge = .bottom,
		minOffset: CGFloat = 10,
		cornerRadius: CGFloat = 20,
        containerColor: UIColor = .black.withAlphaComponent(0.1)
	) -> UIPresentation {
        UIPresentation(
            transition: .default(
                transition: [
                    .move(edge: edge),
                    .constant(\.clipsToBounds, true),
                    .constant(\.layer.cornerRadius, cornerRadius),
                    .constant(\.layer.maskedCorners, .edge(edge.opposite))
                ],
                layout: .padding(
                    NSDirectionalEdgeInsets([edge.opposite: minOffset]),
                    insideSafeArea: NSDirectionalRectEdge(edge.opposite)
                )
                .combine(.alignment(.edge(edge))),
                applyTransitionOnBackControllers: true,
                contextTransparencyDeep: nil
            )
            .withBackground(containerColor),
			interactivity: .swipe(to: edge),
			animation: .default
		)
	}
    
    static func pageSheet(
        from edge: Edge = .bottom,
        minOffset: CGFloat = 10,
        cornerRadius: CGFloat = 10,
        containerColor: UIColor = .pageSheetBackground
    ) -> UIPresentation {
        UIPresentation(
            transition: .default(
                transition: [
                    .move(edge: edge),
                    .constant(\.clipsToBounds, true),
                    .constant(\.layer.cornerRadius, cornerRadius),
                    .constant(\.layer.maskedCorners, .edge(edge.opposite))
                ],
                layout: .padding(
                    NSDirectionalEdgeInsets([edge.opposite: minOffset]),
                    insideSafeArea: NSDirectionalRectEdge(edge.opposite)
                ),
                applyTransitionOnBackControllers: false,
                contextTransparencyDeep: 1
            ) { context in
                guard context.isTopController else { return }
                let vcs = context.direction == .insertion
                    ? Array(context.viewControllers.from.suffix(2))
                    : Array(context.viewControllers.to.suffix(2))
                let view = context.view
                vcs.reversed().enumerated().forEach {
                    let backView = context.view(for: $0.element)
                    let currentTransition = context.removalTransitions[view]?[backView]
                    if context.viewControllers.remaining.contains($0.element) {
                        context.removalTransitions[view, default: [:]][backView] = .transform(
                            to: view,
                            cornerRadius: cornerRadius,
                            up: $0.offset == 0
                        ).reversed
                    }
                    context.removalTransitions[view]?[backView]?.beforeTransitionIfNeeded(view: backView, current: currentTransition)
                }
            } animation: { context, edge in
            } completion: { context, isCompletes in
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
        cornerRadius: CGFloat,
        up: Bool
    ) -> UITransition {
        UITransition(PageSheetModifier(targetView)) { progress, view, initial in
            let (sourceScale, sourceOffset) = transform(
                progress: progress,
                initial: initial,
                cornerRadius: cornerRadius,
                up: up
            )
            view.affineTransform = initial.sourceTransform
                .translatedBy(x: sourceOffset.x, y: sourceOffset.y)
                .scaledBy(x: sourceScale.width, y: sourceScale.height)
        }
    }
    
    static func transform(
        progress: Progress,
        initial: PageSheetModifier.Value,
        cornerRadius: CGFloat,
        up: Bool
    ) -> (scale: CGSize, offset: CGPoint) {
        let k = cornerRadius * 1.2
        var targetRect = initial.targetRect
        targetRect.origin.x += k
        targetRect.size.width -= k * 2
        targetRect.size.height = targetRect.size.width * (initial.sourceRect.height / initial.sourceRect.width)
        if up {
            targetRect.origin.y -= k
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
        
        return (scale, offset)
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
    
    func set(value: Value, to root: Root) {
        root.affineTransform = value.sourceTransform
    }
    
    func value(for root: UIView) -> Value {
        Value(
            sourceTransform: root.affineTransform,
            targetTransform: target?.affineTransform ?? .identity,
            sourceRect: root.superview?.convert(root.frame, to: nil) ?? root.bounds,
            targetRect: target?.superview?.convert(target?.frame ?? .zero, to: nil) ?? target?.bounds ?? root.bounds
        )
    }
    
    struct Value: Equatable {
        
        var sourceTransform: CGAffineTransform
        var targetTransform: CGAffineTransform
        var sourceRect: CGRect
        var targetRect: CGRect
    }
}

private extension UIView {
    
    func scale(_ scale: CGPoint, anchor: UnitPoint) {
        let anchor = isLtrDirection ? anchor : UnitPoint(x: 1 - anchor.x, y: anchor.y)
        let scaleX = scale.x != 0 ? scale.x : 0.0001
        let scaleY = scale.y != 0 ? scale.y : 0.0001
        let xPadding = 1 / scaleX * (anchor.x - anchorPoint.x) * bounds.width
        let yPadding = 1 / scaleY * (anchor.y - anchorPoint.y) * bounds.height
        
        anchorPoint = CGPoint(x: anchor.x, y: anchor.y)
        affineTransform = affineTransform
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: xPadding, y: yPadding)
    }
}

private extension CGFloat {
    
    var notZero: CGFloat { self == 0 ? 0.0001 : self }
}
