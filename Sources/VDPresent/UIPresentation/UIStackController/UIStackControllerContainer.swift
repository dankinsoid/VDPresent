import UIKit

public protocol UIStackControllerContainer: UIView {
 
    func addSubview(_ view: UIView, alignment: ContentAlignment)
    func insertSubview(_ view: UIView, at index: Int, alignment: ContentAlignment)
}

final class UIStackControllerContainerView: UIView, UIStackControllerContainer {

    private var layouts: [UIView: ContentAlignment] = [:] {
        didSet {
            layout()
        }
    }
    
    func addSubview(_ view: UIView, alignment: ContentAlignment) {
        addSubview(view)
        layouts[view] = alignment
    }
    
    func insertSubview(_ view: UIView, at index: Int, alignment: ContentAlignment) {
        insertSubview(view, at: index)
        layouts[view] = alignment
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout()
    }
    
    private func layout() {
        subviews.forEach {
            layouts[$0]?.layout($0, in: frame.size)
        }
    }
}

public struct ContentAlignment {
    
    private let _layout: (UIView, CGSize) -> Void
    
    public func layout(_ view: UIView, in size: CGSize) {
        _layout(view, size)
    }
    
    public static func custom(_ layout: @escaping (UIView, CGSize) -> Void) -> ContentAlignment {
        self.init(_layout: layout)
    }
    
    public static func edges(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> ContentAlignment {
        .custom { view, size in
            let isLtr = view.effectiveUserInterfaceLayoutDirection == .leftToRight
            view.update(
                frame: CGRect(
                    x: isLtr ? leading : trailing,
                    y: top,
                    width: size.width - (leading + trailing),
                    height: size.height - (top + bottom)
                )
            )
        }
    }
}
