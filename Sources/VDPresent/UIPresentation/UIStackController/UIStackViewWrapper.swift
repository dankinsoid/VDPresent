import UIKit

final class UIStackViewWrapper: UIView {
    
    let wrapped: UIView
    
    init(_ view: UIView) {
        wrapped = view
        super.init(frame: view.bounds)
        clipsToBounds = view.clipsToBounds
        addSubview(view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var intrinsicContentSize: CGSize {
        wrapped.intrinsicContentSize
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        wrapped.update(frame: bounds)
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        wrapped.systemLayoutSizeFitting(targetSize)
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        wrapped.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority, verticalFittingPriority: verticalFittingPriority)
    }
}
