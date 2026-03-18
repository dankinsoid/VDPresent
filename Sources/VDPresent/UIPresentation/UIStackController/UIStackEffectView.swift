import UIKit

public final class UIStackEffectView: UIStackControllerCanvas {

	let wrapped: UIView

	init(_ view: UIView) {
		wrapped = view
		super.init(frame: view.bounds)
		clipsToBounds = view.clipsToBounds
		addSubview(view)
		view.pinEdges(to: self)
		Self.installSafeAreaSwizzleIfNeeded()
	}

	@available(*, unavailable)
	public required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override public var intrinsicContentSize: CGSize {
		wrapped.intrinsicContentSize
	}

	override public func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
		wrapped.systemLayoutSizeFitting(targetSize)
	}

	override public func systemLayoutSizeFitting(
		_ targetSize: CGSize,
		withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
		verticalFittingPriority: UILayoutPriority
	) -> CGSize {
		wrapped.systemLayoutSizeFitting(
			targetSize,
			withHorizontalFittingPriority: horizontalFittingPriority,
			verticalFittingPriority: verticalFittingPriority
		)
	}
}

// MARK: - Safe area swizzle

/// UIKit does not propagate safe area insets to a UIView that is the `view`
/// property of a child UIViewController until that child has gone through a
/// full appearance cycle (`beginAppearanceTransition`/`endAppearanceTransition`).
/// In a custom container like `UIStackController`, non-top children inserted
/// in bulk never receive appearance transitions, so their `view.safeAreaInsets`
/// stays at zero — even though the wrapper (UIStackEffectView) above them in
/// the hierarchy has the correct insets.
///
/// This one-time swizzle of `UIView.safeAreaInsets` fixes the issue:
/// when the view's direct superview is a `UIStackEffectView`, it returns
/// the wrapper's safe area insets instead of the (broken) UIKit-computed ones.
/// @ai-generated(guided)
private extension UIStackEffectView {

	private static let swizzleOnce: Void = {
		guard
			let original = class_getInstanceMethod(UIView.self, #selector(getter: UIView.safeAreaInsets)),
			let swizzled = class_getInstanceMethod(UIView.self, #selector(UIView._vdp_swizzled_safeAreaInsets))
		else { return }
		method_exchangeImplementations(original, swizzled)
	}()

	static func installSafeAreaSwizzleIfNeeded() {
		_ = swizzleOnce
	}
}

private extension UIView {

	/// Swizzled replacement for `safeAreaInsets`.
	/// For views whose direct superview is a `UIStackEffectView` (i.e. child
	/// VC views managed by `UIStackController`), returns the wrapper's insets
	/// so the child gets correct safe area regardless of appearance state.
	/// For all other views, calls through to the original implementation.
	@objc dynamic func _vdp_swizzled_safeAreaInsets() -> UIEdgeInsets {
		// After swizzle, _vdp_swizzled_safeAreaInsets points to the original IMP.
		let original = self._vdp_swizzled_safeAreaInsets()
		guard let wrapper = superview as? UIStackEffectView else {
			return original
		}
		let result = wrapper.safeAreaInsets// wrapper.window == nil ? wrapper.safeAreaInsets : wrapper.safeArea(in: nil)
		#if VDPRESENT_LOG
		print("UIStackEffectView safeAreaInsets swizzle: \(result.descr) instead of \(original.descr) for '\(accessibilityIdentifier ?? "nil")'")
		#endif
		return result
	}
}
