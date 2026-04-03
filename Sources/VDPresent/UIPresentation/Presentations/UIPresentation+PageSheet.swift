import SwiftUI
import VDTransition

public extension UIPresentation {

	static var pageSheet: UIPresentation {
		.pageSheet()
	}

	static func pageSheet(
		from edge: Edge = .bottom,
		minOffset: CGFloat = 10,
		cornerRadius: CGFloat = 10,
		containerColor: UIColor = .pageSheetBackground
	) -> UIPresentation {
		UIPresentation(
			transition: .base(transitionID: "pageSheet")
				.environment(\.contentLayout, .padding(
					NSDirectionalEdgeInsets(
						[
							edge.opposite: edge == .leading || edge == .trailing
								? minOffset + UIScreen.main.displayCornerRadius / 2
								: minOffset,
						]
					),
					insideSafeArea: NSDirectionalRectEdge(edge.opposite)
				))
				.environment(\.contentTransition) { _ in
					.combined(
						.move(from: edge),
						.constant(\.clipsToBounds, true),
						.constant(\.layer.cornerRadius, cornerRadius),
						.constant(\.layer.cornerCurve, .continuous),
						.constant(\.layer.maskedCorners, .edge(edge.opposite)),
					)
				}
				.environment(\.recessTransition) { i, context in
					.recessTransform(
						to: context.view,
						edge: edge.opposite,
						cornerRadius: cornerRadius,
						up: i == 1
					)
				}
				.environment(\.overCurrentContext, true)
				.withBackground(containerColor)
				.environment(\.backgroundPlacement, .behindController),
			interactivity: .swipe(to: edge),
			animation: .default
		)
	}
}

public extension UIColor {

	static var pageSheetBackground: UIColor {
		UIColor(displayP3Red: 0.21, green: 0.21, blue: 0.23, alpha: 0.37)
	}
}

private extension UIViewTransition {

	/// Recess transition for pageSheet: scales and translates the behind view
	/// to appear nested inside the sheet's target area.
	///
	/// Uses `UIViewState` to set transform, cornerRadius, cornerMask, and clipping
	/// in the `idle` state (recessed). `willAppear`/`didDisappear` return identity.
	/// @ai-generated(solo)
	static func recessTransform(
		to targetView: UIView,
		edge: Edge,
		cornerRadius: CGFloat,
		up: Bool
	) -> UIViewTransition {
		UIViewTransition { view, identity in
			let sourceRect = view.convert(view.bounds, to: nil)
			let targetRect = targetView.convert(targetView.bounds, to: nil)
			let isLtr = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .leftToRight

			let transform = computeRecessTransform(
				sourceTransform: identity.transform,
				sourceRect: sourceRect,
				targetRect: targetRect,
				edge: edge,
				cornerRadius: cornerRadius,
				isLtr: isLtr,
				up: up
			)
			let targetCornerRadius = computeRecessCornerRadius(
				sourceRect: sourceRect,
				edge: edge,
				cornerRadius: cornerRadius,
				isLtr: isLtr
			)

			return identity
				.with(\.transform, transform)
				.with(\.layer.cornerRadius, targetCornerRadius)
				.with(\.layer.maskedCorners, .edge(edge))
				.with(\.clipsToBounds, true)
		} removed: { _, identity in
			identity
		}
	}

	/// Computes the affine transform that scales and translates the source view
	/// to fit inside the sheet's target area with corner-radius insets.
	/// @ai-generated(solo)
	static func computeRecessTransform(
		sourceTransform: CGAffineTransform,
		sourceRect: CGRect,
		targetRect: CGRect,
		edge: Edge,
		cornerRadius: CGFloat,
		isLtr: Bool,
		up: Bool
	) -> CGAffineTransform {
		let k = cornerRadius * 1.2
		var adjustedRect = targetRect

		switch edge {
		case .top:
			adjustedRect.origin.x += k
			adjustedRect.size.width -= k * 2
			adjustedRect.size.height = adjustedRect.size.width * (targetRect.height / targetRect.width.notZero)
			if up {
				adjustedRect.origin.y -= k
			}

		case .leading, .trailing:
			adjustedRect.origin.y += k
			adjustedRect.size.height -= k * 2
			let newWidth = adjustedRect.size.height * (targetRect.width / targetRect.height.notZero)
			if isLtr == (edge == .leading) {
				adjustedRect.origin.x = adjustedRect.maxX - newWidth
				adjustedRect.size.width = newWidth
				if up {
					adjustedRect.origin.x -= k
				}
			} else {
				adjustedRect.size.width = newWidth
				if up {
					adjustedRect.origin.x += k
				}
			}

		case .bottom:
			adjustedRect.origin.x += k
			adjustedRect.size.width -= k * 2
			let newHeight = adjustedRect.size.width * (targetRect.height / targetRect.width.notZero)
			adjustedRect.origin.y = adjustedRect.maxY - newHeight
			adjustedRect.size.height = newHeight
			if up {
				adjustedRect.origin.y += k
			}
		}

		let scaleX = adjustedRect.width / sourceRect.width.notZero
		let scaleY = adjustedRect.height / sourceRect.height.notZero
		let offsetX = adjustedRect.midX - sourceRect.midX
		let offsetY = adjustedRect.midY - sourceRect.midY

		return sourceTransform
			.translatedBy(x: offsetX, y: offsetY)
			.scaledBy(x: scaleX, y: scaleY)
	}

	/// Computes the target corner radius for the recess effect, using the device's
	/// display corner radius when the view is flush against the matching screen edge.
	/// @ai-generated(solo)
	static func computeRecessCornerRadius(
		sourceRect: CGRect,
		edge: Edge,
		cornerRadius: CGFloat,
		isLtr: Bool
	) -> CGFloat {
		let displayRadius = UIScreen.main.displayCornerRadius
		switch edge {
		case .top:
			return sourceRect.minY == 0 ? displayRadius : cornerRadius
		case .leading, .trailing:
			if isLtr == (edge == .leading) {
				return UIScreen.main.bounds.width == sourceRect.maxX ? displayRadius : cornerRadius
			} else {
				return sourceRect.minX == 0 ? displayRadius : cornerRadius
			}
		case .bottom:
			return UIScreen.main.bounds.height == sourceRect.maxY ? displayRadius : cornerRadius
		}
	}
}
