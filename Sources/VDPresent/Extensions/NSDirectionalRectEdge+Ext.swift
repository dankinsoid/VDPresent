import SwiftUI
import VDTransition

extension NSDirectionalRectEdge {

	init(_ edges: [Edge]) {
		self = []
		for edge in edges {
			switch edge {
			case .top: insert(.top)
			case .leading: insert(.leading)
			case .bottom: insert(.bottom)
			case .trailing: insert(.trailing)
			}
		}
	}

	init(_ edge: Edge, _ others: Edge...) {
		self.init([edge] + others)
	}

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

extension Edge {

	var opposite: Edge {
		switch self {
		case .trailing: return .leading
		case .leading: return .trailing
		case .top: return .bottom
		case .bottom: return .top
		}
	}
}
