import UIKit

public protocol UIStackControllerContainer: UIView {
 
    func addSubview(_ view: UIView, layout: ContentLayout)
    func insertSubview(_ view: UIView, at index: Int, layout: ContentLayout)
}

final class UIStackControllerContainerView: UIView, UIStackControllerContainer {

    private var layouts: [UIView: ContentLayout] = [:] {
        didSet {
            layout()
        }
    }
    
    func addSubview(_ view: UIView, layout: ContentLayout) {
        addSubview(view)
        layouts[view] = layout
    }
    
    func insertSubview(_ view: UIView, at index: Int, layout: ContentLayout) {
        insertSubview(view, at: index)
        layouts[view] = layout
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout()
    }
    
    private func layout() {
        subviews.forEach {
            $0.setNeedsLayout()
            $0.layoutIfNeeded() // Need to update safe area
            layouts[$0]?.layout($0, in: bounds.size, safeArea: safeAreaInsets)
        }
    }
}
