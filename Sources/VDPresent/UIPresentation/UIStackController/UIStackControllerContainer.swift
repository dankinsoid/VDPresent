import UIKit

public class UIStackControllerContainer: UIView {

    private var layouts: [UIView: ContentLayout] = [:]
    
    public func addSubview(_ view: UIView, layout: ContentLayout) {
        addSubview(view)
        layouts[view] = layout
        self.layout()
    }
    
    public func insertSubview(_ view: UIView, at index: Int, layout: ContentLayout) {
        insertSubview(view, at: index)
        layouts[view] = layout
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
        subviews.forEach {
            $0.setNeedsLayout()
            $0.layoutIfNeeded() // Need to update safe area
            layouts[$0, default: .fill].layout($0, in: bounds.size, safeArea: safeAreaInsets)
        }
    }
}
