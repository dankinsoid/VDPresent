import SwiftUI

public struct ContentLayout {
    
    private let _layout: (UIView, CGSize, UIEdgeInsets) -> Void
    
    public func layout(_ view: UIView, in size: CGSize, safeArea: UIEdgeInsets) {
        _layout(view, size, safeArea)
    }
    
    public func combine(_ next: ContentLayout) -> ContentLayout {
        .custom { view, size, insets in
            layout(view, in: size, safeArea: insets)
            next.layout(
                view,
                in: view.bounds.size,
                safeArea: UIEdgeInsets(
                    top: max(0, insets.top - view.frame.minY),
                    left: max(0, insets.left - view.frame.minX),
                    bottom: max(0, insets.bottom - (size.height - view.frame.maxY)),
                    right: max(0, insets.right - (size.width - view.frame.maxX))
                )
            )
        }
    }
    
    public static func custom(_ layout: @escaping (UIView, CGSize, UIEdgeInsets) -> Void) -> ContentLayout {
        self.init(_layout: layout)
    }
    
    public static var fill: ContentLayout {
        .padding()
    }
    
    public static func padding(
        _ edges: NSDirectionalEdgeInsets,
        insideSafeArea: NSDirectionalRectEdge = []
    ) -> ContentLayout {
        .padding(
            top: edges.top,
            leading: edges.leading,
            bottom: edges.bottom,
            trailing: edges.trailing,
            insideSafeArea: insideSafeArea
        )
    }
    
    public static func padding(
        top: CGFloat = 0,
        leading: CGFloat = 0,
        bottom: CGFloat = 0,
        trailing: CGFloat = 0,
        insideSafeArea: NSDirectionalRectEdge = []
    ) -> ContentLayout {
        .custom { view, size, insets in
            let isLtr = view.effectiveUserInterfaceLayoutDirection == .leftToRight
            var insets = insets
            if !insideSafeArea.contains(.top) {
                insets.top = 0
            }
            if !insideSafeArea.contains(.bottom) {
                insets.bottom = 0
            }
            if !insideSafeArea.contains(.leading) {
                if isLtr { insets.left = 0 } else { insets.right = 0 }
            }
            if !insideSafeArea.contains(.trailing) {
                if isLtr { insets.right = 0 } else { insets.left = 0 }
            }
            view.update(
                frame: CGRect(
                    x: (isLtr ? leading : trailing) + insets.left,
                    y: top + insets.top,
                    width: max(0, size.width - (leading + trailing + insets.left + insets.right)),
                    height: max(size.height - (top + bottom + insets.top + insets.bottom), 0)
                )
            )
        }
    }
    
    public static func alignment(
        _ alignment: Alignment
    ) -> ContentLayout {
        .custom { view, size, _ in
            var targetSize: CGSize
            if alignment.horizontal == .fill, alignment.vertical == .fill {
                targetSize = size
            } else if alignment.horizontal == .fill {
                targetSize = CGSize(width: size.width, height: UIView.layoutFittingExpandedSize.height)
            } else if alignment.vertical == .fill {
                targetSize = CGSize(width: UIView.layoutFittingExpandedSize.width, height: size.height)
            } else {
                targetSize = UIView.layoutFittingExpandedSize
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
    
    public static func match(_ view: UIView) -> ContentLayout {
        .custom { [weak view] this, _, _ in
            guard let view, this.window != nil, view.window != nil else { return }
            this.update(frame: view.convert(view.bounds, to: this.superview))
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
            x = isLtr ? max(0, size.width - targetSize.width) : 0
        case .trailing:
            x = isLtr ? 0 : max(0, size.width - targetSize.width)
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
            y = max(0, size.height - targetSize.height)
        case .center:
            y = max(0, size.height - targetSize.height) / 2
        case .fill:
            y = 0
        }
        return CGRect(
            origin: CGPoint(x: x, y: y),
            size: CGSize(
                width: min(targetSize.width, size.width),
                height: min(targetSize.width, size.width)
            )
        )
    }
}
