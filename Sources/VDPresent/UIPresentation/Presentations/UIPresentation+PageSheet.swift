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
					[
						.move(edge: edge),
						.constant(\.clipsToBounds, true),
						.constant(\.layer.cornerRadius, cornerRadius),
						.constant(\.layer.cornerCurve, .continuous),
						.constant(\.layer.maskedCorners, .edge(edge.opposite)),
					]
				}
				.environment(\.recessTransition) { i, context in
					.transform(
						to: context.view,
						edge: edge.opposite,
						cornerRadius: cornerRadius,
						up: i == 1
					)
				}
				.environment(\.overCurrentContext, true)
				.environment(\.backEffectBarrier, true)
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

private extension UITransition<UIView> {

	// @ai-generated(guided)
	static func transform(
		to targetView: UIView,
		edge: Edge,
		cornerRadius: CGFloat,
		up: Bool
	) -> UITransition {
		UITransition(
			\.affineTransform,
			\.globalFrame,
			\.layer.cornerRadius,
			\.layer.maskedCorners,
			\.clipsToBounds
		) { [weak target = targetView] progress, view, initial
			-> (CGAffineTransform, CGRect, CGFloat, CACornerMask, Bool) in
			let (sourceTransform, identityRect, initialCornerRadius, cornerMask, clipsToBounds) = initial
			guard let target else {
				return (sourceTransform, identityRect, initialCornerRadius, cornerMask, clipsToBounds)
			}

			// When multiple recess sub-transitions are .combined(), each receives the
			// previous one's output as `initial`. `sourceTransform` therefore accumulates
			// prior recess transforms, but `identityRect` (globalFrame) stays as the
			// identity-state frame (globalFrame has an empty setter).
			// Derive the effective visual rect by applying the current sourceTransform
			// so that offset/scale/cornerRadius computations see the actual position.
			let effectiveRect = identityRect.applying(sourceTransform)

			let targetRect = target.convert(target.bounds, to: nil)

			let newTransform = computeTransform(
				progress: progress,
				sourceTransform: sourceTransform,
				effectiveRect: effectiveRect,
				targetRect: targetRect,
				edge: edge,
				cornerRadius: cornerRadius,
				isLtr: view.isLtrDirection,
				up: up
			)

			let newCornerRadius = computeCornerRadius(
				progress: progress,
				effectiveRect: effectiveRect,
				edge: edge,
				cornerRadius: cornerRadius,
				isLtr: view.isLtrDirection
			)

			// globalFrame: identityRect returned unchanged — empty setter makes this no-op.
			return (newTransform, identityRect, newCornerRadius, .edge(edge), true)
		}
	}

	static func computeTransform(
		progress: Progress,
		sourceTransform: CGAffineTransform,
		effectiveRect: CGRect,
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

		let scale = CGSize(
			width: progress.value(
				identity: 1,
				transformed: adjustedRect.width / effectiveRect.width.notZero
			),
			height: progress.value(
				identity: 1,
				transformed: adjustedRect.height / effectiveRect.height.notZero
			)
		)

		let offset = CGPoint(
			x: progress.value(
				identity: 0,
				transformed: adjustedRect.midX - effectiveRect.midX
			),
			y: progress.value(
				identity: 0,
				transformed: adjustedRect.midY - effectiveRect.midY
			)
		)

		return sourceTransform
			.translatedBy(x: offset.x, y: offset.y)
			.scaledBy(x: scale.width, y: scale.height)
	}

	static func computeCornerRadius(
		progress: Progress,
		effectiveRect: CGRect,
		edge: Edge,
		cornerRadius: CGFloat,
		isLtr: Bool
	) -> CGFloat {
		let displayRadius = UIScreen.main.displayCornerRadius
		let initialRadius: CGFloat
		switch edge {
		case .top:
			initialRadius = effectiveRect.minY == 0
				? displayRadius
				: cornerRadius
		case .leading, .trailing:
			if isLtr == (edge == .leading) {
				initialRadius = UIScreen.main.bounds.width == effectiveRect.maxX
					? displayRadius
					: cornerRadius
			} else {
				initialRadius = effectiveRect.minX == 0
					? displayRadius
					: cornerRadius
			}
		case .bottom:
			initialRadius = UIScreen.main.bounds.height == effectiveRect.maxY
				? displayRadius
				: cornerRadius
		}
		return progress.value(
			identity: initialRadius,
			transformed: cornerRadius
		)
	}
}

private extension UIView {

	/// Duplicated from VDTransition (internal there).
	/// Empty setter allows `ReferenceWritableKeyPath` for capture-only use.
	var globalFrame: CGRect {
		get { convert(bounds, to: nil) }
		set {}
	}
}
