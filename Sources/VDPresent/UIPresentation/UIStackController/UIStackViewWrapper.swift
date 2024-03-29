import UIKit

public final class UIStackViewWrapper: UIStackControllerContainer {
    
    let wrapped: UIView
    
    init(_ view: UIView) {
        wrapped = view
        super.init(frame: view.bounds)
        clipsToBounds = view.clipsToBounds
        addSubview(view)
        view.pinEdges(to: self)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public var intrinsicContentSize: CGSize {
        wrapped.intrinsicContentSize
    }
    
    override public func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        wrapped.systemLayoutSizeFitting(targetSize)
    }
    
    override public func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        wrapped.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }
}
