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
						.constant(\.layer.maskedCorners, .edge(edge.opposite))
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
				// .screenCornerRadiusRecess(.edge(edge.opposite))
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
			.constant(\.layer.maskedCorners, .edge(edge)),
			.constant(\.layer.cornerRadius, cornerRadius)
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
}
