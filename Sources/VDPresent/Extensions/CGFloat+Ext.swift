import CoreGraphics

extension CGFloat {

	var notZero: CGFloat { self == 0 ? 0.0001 : self }
}

/// Rubber-band resistance curve used by UIKit for overscroll (UIScrollView,
/// sheet drag, etc.).
///
/// Formula: `b = (1 - (1 / ((x * c / d) + 1))) * d`
///
/// As `x` grows, `b` asymptotically approaches `d`, producing the classic
/// "harder to pull the further you go" feel. With `c = 0.55` this matches
/// UIScrollView's native rubber-band constant.
///
/// - Parameters:
///   - x: Distance past the edge, in points. Must be non-negative; pass
///     `abs(...)` if your offset can be signed.
///   - dimension: The dimension along the axis of movement (e.g. the view's
///     height for vertical overscroll). Must be positive.
///   - constant: Resistance constant. `0.55` matches UIKit; smaller values
///     resist more, larger values resist less.
/// - Returns: The rubber-banded distance, always in `[0, dimension)`.
func rubberBand(_ x: CGFloat, dimension d: CGFloat, constant c: CGFloat = 0.55) -> CGFloat {
	guard d > 0 else { return 0 }
	return (1 - (1 / ((x * c / d) + 1))) * d
}
