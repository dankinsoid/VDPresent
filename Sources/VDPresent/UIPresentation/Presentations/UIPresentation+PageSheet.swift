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
								? minOffset + UIScreen.main.displayCornerRadius // TODO: displayCornerRadius should be added for fullscreen stack controller only?
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
	/// Corner radius, corner mask, and clipping are constants (same in both states)
	/// so they appear instantly. Only the transform animates between identity and recessed.
	/// @ai-generated(solo)
	static func recessTransform(
		to targetView: UIView,
		edge: Edge,
		cornerRadius: CGFloat,
		up: Bool
	) -> UIViewTransition {
		.combined(
			recessScale(to: targetView, edge: edge, cornerRadius: cornerRadius, up: up),
			.constant(\.clipsToBounds, true),
//			.constant(\.layer.maskedCorners, .edge(edge)),
			recessCornerRadius(edge: edge, cornerRadius: cornerRadius)
		)
	}

	/// Animates the transform from identity to the recessed (scaled + translated) position.
	/// @ai-generated(solo)
	private static func recessScale(
		to targetView: UIView,
		edge: Edge,
		cornerRadius: CGFloat,
		up: Bool
	) -> UIViewTransition {
		UIViewTransition { view, identity in
			let sourceRect = view.untransformedFrameInWindow
			let targetRect = targetView.untransformedFrameInWindow
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
			return identity.with(\.transform, transform)
		} removed: { _, identity in
			identity
		}
	}

	/// Animates corner radius from the view's current value to the sheet's
	/// smaller corner radius. Uses screen display radius instead of current
	/// value when the view is flush against the matching screen edge.
	/// @ai-generated(guided)
	private static func recessCornerRadius(
		edge: Edge,
		cornerRadius: CGFloat
	) -> UIViewTransition {
		UIViewTransition { _, identity in
			identity.with(\.layer.cornerRadius, cornerRadius)
		} removed: { view, identity in
			let baseRect = view.untransformedFrameInWindow
			let sourceRect = baseRect.applying(identity.transform)
			let isLtr = UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .leftToRight
			let radius = initialCornerRadius(
				view: view,
				sourceRect: sourceRect,
				edge: edge,
				cornerRadius: cornerRadius,
				isLtr: isLtr
			)
			return identity.with(\.layer.cornerRadius, radius)
		}
	}

	/// Computes the affine transform that scales and translates the source view
	/// to fit inside the sheet's target area with corner-radius insets.
	static func computeRecessTransform(
		sourceTransform: CGAffineTransform,
		sourceRect: CGRect,
		targetRect: CGRect,
		edge: Edge,
		cornerRadius: CGFloat,
		isLtr: Bool,
		up: Bool
	) -> CGAffineTransform {
		let edgePadding = cornerRadius * 1.2

		// Scale is determined by the axis perpendicular to the edge:
		// width for top/bottom, height for leading/trailing.
		let scale: CGFloat
		switch edge {
		case .top, .bottom:
			scale = (targetRect.width - edgePadding * 2) / sourceRect.width.notZero
		case .leading, .trailing:
			scale = (targetRect.height - edgePadding * 2) / sourceRect.height.notZero
		}

		let scaledW = sourceRect.width * scale
		let scaledH = sourceRect.height * scale

		// Position the scaled rect: centered on the cross-axis,
		// pinned to the target edge on the main axis, with optional `up` shift.
		var midX: CGFloat
		var midY: CGFloat

		switch edge {
		case .top:
			midX = targetRect.midX
			midY = targetRect.minY + scaledH / 2
			if up { midY -= edgePadding }

		case .bottom:
			midX = targetRect.midX
			midY = targetRect.maxY - scaledH / 2
			if up { midY += edgePadding }

		case .leading, .trailing:
			midY = targetRect.midY
			let pinToEnd = isLtr == (edge == .leading)
			if pinToEnd {
				midX = targetRect.maxX - scaledW / 2
				if up { midX -= edgePadding }
			} else {
				midX = targetRect.minX + scaledW / 2
				if up { midX += edgePadding }
			}
			
			// TODO: displayCornerRadius should be added for fullscreen stack controller only?
			if edge == .leading {
				midX += UIScreen.main.displayCornerRadius
			} else {
				midX -= UIScreen.main.displayCornerRadius
			}
		}

		let offsetX = midX - sourceRect.midX
		let offsetY = midY - sourceRect.midY

		return sourceTransform
			.translatedBy(x: offsetX, y: offsetY)
			.scaledBy(x: scale, y: scale)
	}

	/// Returns the view's starting corner radius: screen display radius when
	/// the view is flush against the matching edge, otherwise the view's current value.
	/// @ai-generated(guided)
	static func initialCornerRadius(
		view: UIView,
		sourceRect: CGRect,
		edge: Edge,
		cornerRadius: CGFloat,
		isLtr: Bool
	) -> CGFloat {
		let displayRadius = UIScreen.main.displayCornerRadius
		let isFlush: Bool
		switch edge {
		case .top:
			isFlush = sourceRect.minY == 0
		case .leading, .trailing:
			if isLtr == (edge == .leading) {
				isFlush = UIScreen.main.bounds.width == sourceRect.maxX
			} else {
				isFlush = sourceRect.minX == 0
			}
		case .bottom:
			isFlush = UIScreen.main.bounds.height == sourceRect.maxY
		}
		return isFlush ? displayRadius : view.layer.cornerRadius
	}
}

private extension UIView {

	/// Frame in window coordinates ignoring the view's own transform.
	/// Uses `bounds.size` (unaffected by transform) and `center` (= layer.position,
	/// stored in superview coordinates independently of transform).
	/// @ai-generated(solo)
	var untransformedFrameInWindow: CGRect {
		let size = bounds.size
		let globalCenter = superview?.convert(center, to: nil) ?? center
		return CGRect(
			x: globalCenter.x - size.width / 2,
			y: globalCenter.y - size.height / 2,
			width: size.width,
			height: size.height
		)
	}
}
