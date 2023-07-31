import SwiftUI
import QuartzCore
import VDTransition

public extension UIPresentation {
    
    static var pageCurl: UIPresentation {
        .pageCurl()
    }
    
    static func pageCurl(
        from edge: Edge = .trailing
    ) -> UIPresentation {
        UIPresentation(
            transition: .caAnimation { context in
                guard context.isTopController else { return nil }
                return CATransition.curlPage(
                    from: edge,
                    direction: context.direction,
                    isLTR: context.view.isLtrDirection
                )
            }
        )
    }
}

private extension UIPresentation.Context {
    
    var caTransitions: [Weak<UIViewController>: CATransition] {
        get { cache[\.caTransitions] ?? [:] }
        nonmutating set { cache[\.caTransitions] = newValue }
    }
}

extension CATransition {
    
    static func curlPage(
        from edge: Edge,
        direction: TransitionDirection = .insertion,
        isLTR: Bool
    ) -> CATransition {
        let transition = CATransition()
        transition.type = CATransitionType(rawValue: direction == .insertion ? "pageCurl" : "pageUnCurl")
//        let edge = direction == .insertion ? edge : edge.opposite
        switch edge {
        case .top:
            transition.subtype = .fromTop
        case .leading, .trailing:
            transition.subtype = isLTR == (edge == .leading)
            ? .fromLeft
            : .fromRight
        case .bottom:
            transition.subtype = .fromBottom
        }
//        transition.startProgress = 0
//        transition.endProgress = 1
//        transition.fillMode = .forwards
        transition.isRemovedOnCompletion = true
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut);
        return transition
    }
}
