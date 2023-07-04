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
                    NSDirectionalEdgeInsets(
                        [
                            edge.opposite: edge == .leading || edge == .trailing
                                ? minOffset + UIScreen.main.displayCornerRadius / 2
                                : minOffset
                        ]
                    ),
                    insideSafeArea: NSDirectionalRectEdge(edge.opposite)
                ),
                applyTransitionOnBackControllers: false,
                contextTransparencyDeep: 1
            ) { context in
                guard context.isTopController else {
                    return
                }
                let vcs = context.direction == .insertion
                    ? Array(context.viewControllers.from.suffix(2))
                    : Array(context.viewControllers.to.suffix(2))
                let view = context.view
                vcs.reversed().enumerated().forEach {
                    let backView = context.view(for: $0.element)
                    context.removalTransitions[view]?[backView] = nil
                    let currentTransition = context.pageSheetTransitions[view]?[backView]
                    if context.viewControllers.remaining.contains($0.element) {
                        context.pageSheetTransitions[view, default: [:]][backView] = .transform(
                            to: view,
                            edge: edge.opposite,
                            cornerRadius: cornerRadius,
                            up: $0.offset == 0
                        ).reversed
                    }
                    context.pageSheetTransitions[view]?[backView]?.beforeTransitionIfNeeded(view: backView, current: currentTransition)
                }
            } animation: { context, edge in
                let view = context.view
                context.pageSheetTransitions[view]?.forEach {
                    if let backView = $0.key.value {
                        $0.value.update(progress: context.direction.at(edge), view: backView)
                    }
                }
            } completion: { context, completed in
                let array = completed
                    ? context.viewControllers.toRemove
                    : context.viewControllers.toInsert
                if array.contains(context.viewController) {
                    context.pageSheetTransitions[context.view] = nil
                }
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
            let (sourceScale, sourceOffset) = transform(
                progress: progress,
                initial: initial,
                edge: edge,
                cornerRadius: cornerRadius,
                isLtr: view.isLtrDirection,
                up: up
            )
            view.affineTransform = initial.sourceTransform
                .translatedBy(x: sourceOffset.x, y: sourceOffset.y)
                .scaledBy(x: sourceScale.width, y: sourceScale.height)
            
            view.clipsToBounds = true
            view.layer.maskedCorners = .edge(edge)
            
            let displayRadius = UIScreen.main.displayCornerRadius
            let initialRadius: CGFloat
            switch edge {
            case .top:
                initialRadius = initial.sourceRect.minY == 0
                    ? displayRadius
                    : cornerRadius
            case .leading, .trailing:
                if view.isLtrDirection == (edge == .leading) {
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
            view.layer.cornerRadius = progress.value(
                identity: initialRadius,
                transformed: cornerRadius
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
    ) -> (scale: CGSize, offset: CGPoint) {
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
        
        return (scale, offset)
    }
}

extension UIPresentation.Context {
    
    var pageSheetTransitions: [Weak<UIView>: [Weak<UIView>: UITransition<UIView>]] {
        get {
            cache[\.pageSheetTransitions] ?? [:]
        }
        nonmutating set {
            cache[\.pageSheetTransitions] = newValue
        }
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

private extension UIScreen {
    
    private static let cornerRadiusKey: String = ["Radius", "Corner", "display", "_"].reversed().joined()
    
    /// The corner radius of the display. Uses a private property of `UIScreen`,
    /// and may report 0 if the API changes.
    var displayCornerRadius: CGFloat {
        guard let cornerRadius = self.value(forKey: Self.cornerRadiusKey) as? CGFloat else {
            return 0
        }
        return cornerRadius
    }
}
