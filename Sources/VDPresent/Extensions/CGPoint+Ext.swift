import CoreGraphics

extension CGPoint {

	static func + (_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
		CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}

	static func - (_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
		CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
	}
}
