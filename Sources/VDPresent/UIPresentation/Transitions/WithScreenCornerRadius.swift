import UIKit
import VDTransition

public extension UIPresentation.Transition {
	
//	func screenCornerRadius(
//		_ coners: CACornerMask = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMinYCorner]
//	) -> UIPresentation.Transition {
//		UIPresentation.Transition(
//			transitionID: transitionID,
//			environment: environment
//		) { ctx in
//			Self.prepareScreenCornerRadius(context: ctx)
//			prepare(ctx)
//		} animation: { ctx in
//			Self.animateScreenCornerRadius(context: ctx)
//			animation(ctx)
//		} completion: { ctx, completed in
//			Self.completeScreenCornerRadius(context: ctx)
//			completion(ctx, completed)
//		}
//	}

	func screenCornerRadiusRecess(
		_ corners: CACornerMask = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMinYCorner]
	) -> UIPresentation.Transition {
		transformEnvironment(\.recessTransition) { transition in
			return { depth, ctx in
				let transition = transition(depth, ctx)
				return .combined(transition, .toScreenCornerRadiusIfMatch(corners: corners))
			}
		}
	}
}

extension UIViewTransition {

	public static func toScreenCornerRadiusIfMatch(
		corners: CACornerMask = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMinYCorner]
	) -> UIViewTransition {
		UIViewTransition { view, identity in
			let sourceRect = view.untransformedFrameInWindow

			let displayRadius = UIScreen.main.displayCornerRadius
			var flushedCorners: CACornerMask = []
			
			if corners.contains(.layerMinXMinYCorner), sourceRect.minX == 0, sourceRect.minY == 0 {
				flushedCorners.insert(.layerMinXMinYCorner)
			}
			if corners.contains(.layerMaxXMaxYCorner), sourceRect.maxX ==  UIScreen.main.bounds.width, sourceRect.maxY == UIScreen.main.bounds.height {
				flushedCorners.insert(.layerMaxXMaxYCorner)
			}
			if corners.contains(.layerMinXMaxYCorner), sourceRect.minX == 0, sourceRect.maxY == UIScreen.main.bounds.height {
				flushedCorners.insert(.layerMinXMaxYCorner)
			}
			if corners.contains(.layerMaxXMinYCorner), sourceRect.maxY == UIScreen.main.bounds.height, sourceRect.minY == 0 {
				flushedCorners.insert(.layerMaxXMinYCorner)
			}
			
			guard !flushedCorners.isEmpty else { return identity }

			return identity
				.with(\.layer.maskedCorners, flushedCorners)
				.with(\.layer.cornerRadius, displayRadius)
		} removed: { view, identity in
			identity
		}
	}

	public static func fromScreenCornerRadiusIfMatch(
		corners: CACornerMask = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMinXMinYCorner]
	) -> UIViewTransition {
		let result = toScreenCornerRadiusIfMatch(corners: corners)
		return UIViewTransition(
			willAppear: result.idle,
			idle: result.willAppear,
			didDisappear: result.idle
		)
	}
}

private extension UIPresentation.Transition {
	
	@MainActor
	static func prepareScreenCornerRadius(context: UIPresentation.Context)  {
		
	}

	@MainActor
	static func animateScreenCornerRadius(context: UIPresentation.Context)  {
		
	}

	@MainActor
	static func completeScreenCornerRadius(context: UIPresentation.Context)  {
		
	}
}
