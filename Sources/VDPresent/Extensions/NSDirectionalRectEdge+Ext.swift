import UIKit
import VDTransition

extension NSDirectionalRectEdge {
    
    static var horizontal: NSDirectionalRectEdge {
        [.leading, .trailing]
    }
    
    static var vertical: NSDirectionalRectEdge {
        [.top, .bottom]
    }
}

extension UIView {
    
    var rightEdge: NSDirectionalRectEdge {
        isLtrDirection ? .trailing : .leading
    }
    
    func nsDirectionalEdgeInsets(
        top: CGFloat,
        left: CGFloat,
        bottom: CGFloat,
        right: CGFloat
    ) -> NSDirectionalEdgeInsets {
        isLtrDirection
        ? NSDirectionalEdgeInsets(top: top, leading: left, bottom: bottom, trailing: right)
        : NSDirectionalEdgeInsets(top: top, leading: right, bottom: bottom, trailing: left)
    }
}
