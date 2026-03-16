import SwiftUI

/// Describes how a child view should be positioned and sized inside its superview using Auto Layout constraints.
///
/// `ContentLayout` is a value type that wraps a constraint-producing closure. You compose layouts using
/// the built-in factories (``fill``, ``padding(_:insideSafeArea:)``, ``alignment(_:)``) or supply
/// your own via ``constraints(_:)``. Multiple layouts can be merged with ``combine(_:)``.
///
/// Usage:
/// ```swift
/// layout.constraints(childView, in: containerView)
/// ```
/// This sets `translatesAutoresizingMaskIntoConstraints = false` on the child and activates the
/// produced constraints.
public struct ContentLayout {

	private let _constraints: (_ view: UIView, _ superview: UIView) -> [NSLayoutConstraint]
	//    case layoutSubviews((UIView, CGSize, UIEdgeInsets) -> Void)
//
	//    public func layout(_ view: UIView, in size: CGSize, safeArea: UIEdgeInsets) {
	//        switch self {
	//        case let .layoutSubviews(_layout):
	//            _layout(view, size, safeArea)
	//        default:
	//            break
	//        }
	//    }

	/// Applies this layout to `view` inside `superview`.
	///
	/// Sets `translatesAutoresizingMaskIntoConstraints = false` and activates the generated constraints.
	/// - Parameters:
	///   - view: The view to position.
	///   - superview: The container view that owns the layout anchors.
	public func constraints(_ view: UIView, in superview: UIView) {
		view.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate(
			_constraints(view, superview)
		)
	}

	/// Returns a new layout that applies both `self` and `next` constraints.
	/// - Parameter next: The layout whose constraints are appended after the receiver's.
	/// - Returns: A merged `ContentLayout`.
	public func combine(_ next: ContentLayout) -> ContentLayout {
		.constraints { view, superview in
			_constraints(view, superview) + next._constraints(view, superview)
		}
	}

	/// Creates a layout from an arbitrary constraint-producing closure.
	/// - Parameter constraints: Closure that receives the child view and its superview and returns
	///   the constraints to activate. The closure is called lazily each time ``constraints(_:in:)`` is invoked.
	/// - Returns: A `ContentLayout` backed by the provided closure.
	public static func constraints(
		_ constraints: @escaping (_ view: UIView, _ superview: UIView) -> [NSLayoutConstraint]
	) -> ContentLayout {
		self.init(_constraints: constraints)
	}

	/// A layout that pins all four edges of the view to its superview (zero insets).
	public static var fill: ContentLayout {
		//        .layoutSubviews { view, size, _ in
		//            view.update(frame: CGRect(origin: .zero, size: size))
		//        }
		.constraints { view, superview in
			[
				view.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
				view.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
				view.topAnchor.constraint(equalTo: superview.topAnchor),
				view.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
			]
		}
	}

	/// A layout that pins each edge with an inset, optionally relative to the safe-area layout guide.
	/// - Parameters:
	///   - edges: Insets to apply on each side (directional, so `leading`/`trailing` follow the layout direction).
	///   - insideSafeArea: The set of edges that should be anchored to `safeAreaLayoutGuide` instead of the
	///     superview's raw edges. Defaults to `[]` (no safe-area anchoring).
	/// - Returns: A `ContentLayout` that produces four edge constraints.
	public static func padding(
		_ edges: NSDirectionalEdgeInsets,
		insideSafeArea: NSDirectionalRectEdge = []
	) -> ContentLayout {
		.constraints { view, superview in
			var result: [NSLayoutConstraint] = []
			if insideSafeArea.contains(.leading) {
				result.append(
					view.leadingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.leadingAnchor, constant: edges.leading)
				)
			} else {
				result.append(
					view.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: edges.leading)
				)
			}
			if insideSafeArea.contains(.trailing) {
				result.append(
					view.trailingAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.trailingAnchor, constant: -edges.trailing)
				)
			} else {
				result.append(
					view.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -edges.trailing)
				)
			}
			if insideSafeArea.contains(.top) {
				result.append(
					view.topAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.topAnchor, constant: edges.top)
				)
			} else {
				result.append(
					view.topAnchor.constraint(equalTo: superview.topAnchor, constant: edges.top)
				)
			}
			if insideSafeArea.contains(.bottom) {
				result.append(
					view.bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor, constant: -edges.bottom)
				)
			} else {
				result.append(
					view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -edges.bottom)
				)
			}
			return result
		}
	}

	/// A layout that positions the view according to the specified alignment within its superview.
	///
	/// For `.fill` on an axis the view is pinned to both edges; for point alignments (`.top`, `.center`, etc.)
	/// only the relevant anchor is constrained, leaving the view free to size itself on that axis.
	/// - Parameter alignment: The desired horizontal and vertical alignment.
	/// - Returns: A `ContentLayout` with the corresponding anchor constraints.
	public static func alignment(
		_ alignment: Alignment
	) -> ContentLayout {
		.constraints { view, superview in
			var result: [NSLayoutConstraint] = []
			switch alignment.horizontal {
			case .trailing:
				result.append(view.trailingAnchor.constraint(equalTo: superview.trailingAnchor))
			case .leading:
				result.append(view.leadingAnchor.constraint(equalTo: superview.leadingAnchor))
			case .center:
				result.append(view.centerXAnchor.constraint(equalTo: superview.centerXAnchor))
			case .fill:
				result.append(view.leadingAnchor.constraint(equalTo: superview.leadingAnchor))
				result.append(view.trailingAnchor.constraint(equalTo: superview.trailingAnchor))
			}
			switch alignment.vertical {
			case .top:
				result.append(view.topAnchor.constraint(equalTo: superview.topAnchor))
			case .bottom:
				result.append(view.bottomAnchor.constraint(equalTo: superview.bottomAnchor))
			case .center:
				result.append(view.centerYAnchor.constraint(equalTo: superview.centerYAnchor))
			case .fill:
				result.append(view.topAnchor.constraint(equalTo: superview.topAnchor))
				result.append(view.bottomAnchor.constraint(equalTo: superview.bottomAnchor))
			}
			return result
		}
		//        .layoutSubviews { view, size, _ in
		//            var targetSize: CGSize
		//            if alignment.horizontal == .fill, alignment.vertical == .fill {
		//                targetSize = size
		//            } else if alignment.horizontal == .fill {
		//                targetSize = CGSize(width: size.width, height: UIView.layoutFittingExpandedSize.height)
		//            } else if alignment.vertical == .fill {
		//                targetSize = CGSize(width: UIView.layoutFittingExpandedSize.width, height: size.height)
		//            } else {
		//                targetSize = UIView.layoutFittingExpandedSize
		//            }
		//            targetSize = view.systemLayoutSizeFitting(
		//                targetSize,
		//                withHorizontalFittingPriority: alignment.horizontal == .fill ? .required : .defaultLow,
		//                verticalFittingPriority: alignment.vertical == .fill ? .required : .defaultLow
		//            )
		//            if alignment.horizontal == .fill {
		//                targetSize.width = size.width
		//            }
		//            if alignment.vertical == .fill {
		//                targetSize.height = size.height
		//            }
		//            view.update(
		//                frame: view.frame(of: targetSize, in: size, alignment: alignment)
		//            )
		//        }
	}

	//    public static func match(_ view: UIView) -> ContentLayout {
	//        .layoutSubviews { [weak view] this, _, _ in
	//            guard let view, this.window != nil, view.window != nil else { return }
	//            this.update(frame: view.convert(view.bounds, to: this.superview))
	//        }
	//    }

	/// Combined horizontal and vertical alignment descriptor used by ``alignment(_:)``.
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

	/// Vertical positioning options for ``Alignment``.
	public enum VAlignment {

		case top
		case bottom
		case center
		case fill
	}

	/// Horizontal positioning options for ``Alignment``.
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
