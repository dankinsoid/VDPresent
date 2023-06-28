import SwiftUI

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
            $0.layoutIfNeeded()
            layouts[$0]?.layout($0, in: frame.size)
        }
    }
}

public struct ContentLayout {
    
    private let _layout: (UIView, CGSize) -> Void
    
    public func layout(_ view: UIView, in size: CGSize) {
        _layout(view, size)
    }
    
    public func combine(_ next: ContentLayout) -> ContentLayout {
        .custom { view, size in
            layout(view, in: size)
            next.layout(view, in: view.bounds.size)
        }
    }
    
    public static func custom(_ layout: @escaping (UIView, CGSize) -> Void) -> ContentLayout {
        self.init(_layout: layout)
    }
    
    public static var fill: ContentLayout {
        .padding()
    }
    
    public static func padding(
        _ edges: NSDirectionalEdgeInsets
    ) -> ContentLayout {
        .padding(
            top: edges.top,
            leading: edges.leading,
            bottom: edges.bottom,
            trailing: edges.trailing
        )
    }
    
    public static func padding(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0
    ) -> ContentLayout {
        .custom { view, size in
            let isLtr = view.effectiveUserInterfaceLayoutDirection == .leftToRight
            view.update(
                frame: CGRect(
                    x: isLtr ? leading : trailing,
                    y: top,
                    width: max(0, size.width - (leading + trailing)),
                    height: max(size.height - (top + bottom), 0)
                )
            )
        }
    }
    
    public static func alignment(
        _ alignment: Alignment
    ) -> ContentLayout {
        .custom { view, size in
            view.update(
                frame: view.frame(of: view.bounds.size, in: size, alignment: alignment)
            )
            var targetSize: CGSize
            if alignment.horizontal == .fill, alignment.vertical == .fill {
                targetSize = size
            } else if alignment.horizontal == .fill {
                targetSize = CGSize(width: size.width, height: UIView.layoutFittingCompressedSize.height)
            } else if alignment.vertical == .fill {
                targetSize = CGSize(width: UIView.layoutFittingCompressedSize.width, height: size.height)
            } else {
                targetSize = UIView.layoutFittingCompressedSize
            }
            targetSize = view.systemLayoutSizeFitting(
                targetSize,
                withHorizontalFittingPriority: alignment.horizontal == .fill ? .required : .fittingSizeLevel,
                verticalFittingPriority: alignment.vertical == .fill ? .required : .fittingSizeLevel
            )
            if alignment.horizontal == .fill {
                targetSize.width = size.width
            }
            if alignment.vertical == .fill {
                targetSize.height = size.height
            }
            view.update(
                frame: view.frame(of: targetSize, in: size, alignment: alignment)
            )
        }
    }
    
    public struct Alignment {
        
        public var vertical: VAlignment
        public var horizontal: HAlignment
        
        public init(vertical: VAlignment, horizontal: HAlignment) {
            self.vertical = vertical
            self.horizontal = horizontal
        }
        
        public static var fill: Alignment {
            Alignment(vertical: .fill, horizontal: .fill)
        }
        
        public static func edge(_ edge: Edge) -> Alignment {
            switch edge {
            case .top: return .top
            case .leading: return .leading
            case .bottom: return .bottom
            case .trailing: return .trailing
            }
        }
        
        public static var top: Alignment {
            Alignment(vertical: .top, horizontal: .fill)
        }
        
        public static var bottom: Alignment {
            Alignment(vertical: .bottom, horizontal: .fill)
        }
        
        public static var leading: Alignment {
            Alignment(vertical: .fill, horizontal: .leading)
        }
        
        public static var trailing: Alignment {
            Alignment(vertical: .fill, horizontal: .trailing)
        }
    }
    
    public enum VAlignment {
        
        case top
        case bottom
        case center
        case fill
    }
    
    public enum HAlignment {
        
        case trailing
        case leading
        case center
        case fill
    }
}

private extension UIView {
    
    func frame(of targetSize: CGSize, in size: CGSize, alignment: ContentLayout.Alignment) -> CGRect {
        let isLtr = effectiveUserInterfaceLayoutDirection == .leftToRight
        let x: CGFloat
        switch alignment.horizontal {
        case .leading:
            x = isLtr ? size.width - targetSize.width : 0
        case .trailing:
            x = isLtr ? 0 : size.width - targetSize.width
        case .center:
            x = (size.width - targetSize.width) / 2
        case .fill:
            x = 0
        }
        let y: CGFloat
        switch alignment.vertical {
        case .top:
            y = 0
        case .bottom:
            y = size.height - targetSize.height
        case .center:
            y = (size.height - targetSize.height) / 2
        case .fill:
            y = 0
        }
        return CGRect(
            origin: CGPoint(x: x, y: y),
            size: targetSize
        )
    }
}
