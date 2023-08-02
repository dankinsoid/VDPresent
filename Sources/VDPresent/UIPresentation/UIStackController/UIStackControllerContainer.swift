import UIKit

public class UIStackControllerContainer: UIView {

    private var layouts: [UIView: ContentLayout] = [:]
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        afterInit()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        afterInit()
    }
    
    public func addSubview(_ view: UIView, layout: ContentLayout) {
        addSubview(view)
        addedSubview(view, layout: layout)
    }
    
    public func insertSubview(_ view: UIView, at index: Int, layout: ContentLayout) {
        insertSubview(view, at: index)
        addedSubview(view, layout: layout)
    }
    
    private func addedSubview(_ view: UIView, layout: ContentLayout) {
        layouts[view] = layout
        layout.constraints(view, in: self)
        setNeedsLayout()
        layoutIfNeeded()
        self.layout()
    }
    
    public func remove(subview: UIView) {
        subview.removeFromSuperview()
        layouts[subview] = nil
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        layout()
    }
    
    private func layout() {
//        subviews.forEach {
//            $0.setNeedsLayout()
//            $0.layoutIfNeeded() // Need to update safe area
//            layouts[$0, default: .fill].layout($0, in: bounds.size, safeArea: safeAreaInsets)
//        }
    }
    
    private func afterInit() {
        autoresizingMask = []
        translatesAutoresizingMaskIntoConstraints = false
    }
}
