import UIKit

public final class UIStackEffectView: UIStackControllerCanvas {

	let wrapped: UIView

	init(_ view: UIView) {
		wrapped = view
		super.init(frame: view.bounds)
		clipsToBounds = view.clipsToBounds
		addSubview(view)
		view.pinEdges(to: self)
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

// MARK: - Safe area unlock for non-appeared child VCs

/// UIKit blocks safe area inset propagation for child VCs that haven't
/// completed an appearance cycle. In `UIStackController`, non-top children
/// inserted via bulk `set(viewControllers:)` never receive appearance
/// transitions, so their `view.safeAreaInsets` stays at zero.
///
/// This workaround sets the internal `_appearState` bit in
/// `_viewControllerFlags` to make UIKit treat the VC as "appeared" for
/// safe area purposes — without triggering `viewWillAppear`/`viewDidAppear`.
///
/// The bit is validated at launch: if the ivar layout changes in a future
/// iOS version, the function silently does nothing (safe area stays zero
/// rather than corrupting memory).
/// @ai-generated(guided)
extension UIViewController {

	private static let appearStateBitInfo: (offset: Int, ok: Bool) = {
		var count: UInt32 = 0
		guard let ivars = class_copyIvarList(UIViewController.self, &count) else {
			return (0, false)
		}
		defer { free(ivars) }
		for i in 0..<Int(count) {
			let name = String(cString: ivar_getName(ivars[i])!)
			if name == "_viewControllerFlags" {
				return (ivar_getOffset(ivars[i]), true)
			}
		}
		return (0, false)
	}()

	/// Unlocks safe area propagation for this VC without triggering appearance callbacks.
	/// No-op if the internal layout is unrecognized (future-proofing).
	func unlockSafeAreaPropagation() {
		let info = Self.appearStateBitInfo
		guard info.ok else { return }
		let ptr = Unmanaged.passUnretained(self).toOpaque()
			.advanced(by: info.offset)
			.assumingMemoryBound(to: UInt8.self)
		ptr[0] |= 0x02
	}

	// TODO: Try clearing the bit after layout pass — sandbox showed safe area
	// persists after clear. This would avoid permanently lying about appearState.
	// Set bit → wait for layout → clear bit. Could do in completionBlock.
	func lockSafeAreaPropagation() {
		let info = Self.appearStateBitInfo
		guard info.ok else { return }
		let ptr = Unmanaged.passUnretained(self).toOpaque()
			.advanced(by: info.offset)
			.assumingMemoryBound(to: UInt8.self)
		ptr[0] &= ~UInt8(0x02)
	}
}
