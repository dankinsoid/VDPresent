import SwiftUI
import VDTransition

extension UITransition<UIView> {
    
    public static func screenCorners(
        _ edge: Edge,
        from value: CGFloat? = nil
    ) -> UITransition {
        .screenCorners(mask: .edge(edge), from: value)
    }
    
    public static func screenCorners(
        mask: CACornerMask,
        from value: CGFloat? = nil
    ) -> UITransition {
        [
            .value(\.layer.cornerRadius, value ?? 0, default: UIScreen.main.displayCornerRadius),
            .constant(\.layer.maskedCorners, mask),
            .constant(\.clipsToBounds, true)
        ]
    }
}

extension TransitionDirection {
    
    var reversed: TransitionDirection {
        switch self {
        case .insertion: return .removal
        case .removal: return .insertion
        }
    }
}
