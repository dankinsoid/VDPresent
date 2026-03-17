import UIKit

/// A full-screen layer that acts as the drawing canvas for one child view
/// controller inside a `UIStackController`.
///
/// `UIStackController` maintains one `UIStackControllerCanvas` per entry in
/// `viewControllers`. Every container is pinned to the edges of the stack's
/// root view (`UIStackControllerView`), so at rest they all occupy the full
/// screen and only the topmost one is visible. During a transition the stack
/// reorders and animates these layers according to the active `UIPresentation`.
///
/// Subviews are added through the layout-aware overloads rather than the
/// plain `UIView` API, so each subview carries an associated `ContentLayout`
/// descriptor that drives its frame during layout passes:
///
/// ```swift
/// container.addSubview(someView, layout: .fill)
/// container.addSubview(badgeView, layout: .center(size: CGSize(width: 44, height: 44)))
/// container.remove(subview: badgeView)
/// ```
///
/// The direct subclass `UIStackEffectView` is the concrete container used
/// in practice — it wraps a child view controller's `view` and proxies its
/// size methods so the transition system can measure it correctly.
///
/// - Note: The `ContentLayout`-based frame calculation inside `layout()` is
///   currently commented out; subview positioning relies entirely on
///   Auto Layout constraints installed by `ContentLayout.constraints(_:in:)`.
public class UIStackControllerCanvas: UIView {

	private var layouts: [UIView: ContentLayout] = [:]

	override public init(frame: CGRect) {
		super.init(frame: frame)
		afterInit()
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		afterInit()
	}

	/// Adds `view` as a subview and registers the given layout for it.
	///
	/// Prefer this over `addSubview(_:)` so the container knows how to position
	/// the view. Constraints produced by `layout` are activated immediately.
	/// - Parameters:
	///   - view: The view to add.
	///   - layout: Positioning descriptor; e.g. `.fill`, `.padding(…)`, `.alignment(…)`.
	public func addSubview(_ view: UIView, layout: ContentLayout) {
		addSubview(view)
		addedSubview(view, layout: layout)
	}

	/// Inserts `view` at the given z-order index and registers the given layout for it.
	///
	/// Equivalent to `addSubview(_:layout:)` but lets you control the subview stacking order.
	/// - Parameters:
	///   - view: The view to insert.
	///   - index: Z-order index among the receiver's subviews.
	///   - layout: Positioning descriptor applied immediately after insertion.
	public func insertSubview(_ view: UIView, at index: Int, layout: ContentLayout) {
		insertSubview(view, at: index)
		addedSubview(view, layout: layout)
	}

	private func addedSubview(_ view: UIView, layout: ContentLayout) {
		layouts[view] = layout
		layout.constraints(view, in: self)
		setNeedsLayout()
		layoutIfNeeded()
		self.layout()
	}

	/// Removes `subview` from the view hierarchy and clears its registered layout.
	///
	/// Use this instead of `removeFromSuperview()` so the container drops the
	/// associated `ContentLayout` entry and avoids a stale reference.
	/// - Parameter subview: A subview previously added via `addSubview(_:layout:)` or
	///   `insertSubview(_:at:layout:)`.
	public func remove(subview: UIView) {
		subview.removeFromSuperview()
		layouts[subview] = nil
	}

	override public func layoutSubviews() {
		super.layoutSubviews()
		layout()
	}

	private func layout() {
		//        subviews.forEach {
		//            $0.setNeedsLayout()
		//            $0.layoutIfNeeded() // Need to update safe area
		//            layouts[$0, default: .fill].layout($0, in: bounds.size, safeArea: safeAreaInsets)
		//        }
	}

	private func afterInit() {
		autoresizingMask = []
		translatesAutoresizingMaskIntoConstraints = false
	}
}
