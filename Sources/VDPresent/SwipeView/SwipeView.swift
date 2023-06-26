import UIKit

final class SwipeView: UIScrollView, UIScrollViewDelegate {

	private let content = UIView()
	private var contentConstraints: [NSLayoutConstraint] = []
	private var lastLayoutSize: CGSize = .zero

	weak var visibleContent: UIView? {
		didSet {
			if let content = visibleContent, content !== oldValue {
				visibleContainer.addSubview(content)
				content.pinEdges(to: visibleContainer)
			}
		}
	}

	private(set) var visibleContainer = UIView()
	var instances: [Key: Instance] = [:]
	var edges: NSDirectionalRectEdge {
		instances.reduce([]) { $0.union($1.key.edge) }
	}

	var initialOffset: CGPoint {
		CGPoint(
			x: edges.contains(rightEdge) ? frame.width : 0,
			y: edges.contains(.bottom) ? frame.height : 0
		)
	}

	subscript(_ key: Key) -> Instance {
		if let result = instances[key] {
			return result
		}
		let result = Instance(scroll: self, key: key)
		instances[key] = result
		reset()
		return result
	}

	init() {
		super.init(frame: .zero)
		afterInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	private func afterInit() {
		delegate = self
		isPagingEnabled = true
		contentInsetAdjustmentBehavior = .never
		isDirectionalLockEnabled = true
		showsHorizontalScrollIndicator = false
		showsVerticalScrollIndicator = false

		addSubview(content)
		content.translatesAutoresizingMaskIntoConstraints = false
		content.addSubview(visibleContainer)
		visibleContainer.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			widthAnchor.constraint(equalTo: visibleContainer.widthAnchor),
			heightAnchor.constraint(equalTo: visibleContainer.heightAnchor),
			visibleContainer.leftAnchor.constraint(equalTo: content.leftAnchor),
			visibleContainer.topAnchor.constraint(equalTo: content.topAnchor),
		])
		content.frame.size = CGSize(width: frame.width * 2, height: frame.height)
		content.pinEdges(to: contentLayoutGuide)
	}

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		instances.forEach { $0.value.didScroll() }
		visibleContainer.transform = CGAffineTransform(
			translationX: scrollView.contentOffset.x,
			y: scrollView.contentOffset.y
		)
	}

	func scrollViewDidEndDecelerating(_: UIScrollView) {
		instances.forEach { $0.value.didEndDecelerating() }
		reset()
	}

	func scrollViewWillBeginDragging(_: UIScrollView) {
		guard Set(instances.map(\.key.edge.rawValue)).count == 1 else { return }
		(instances.first { $0.key.startFromEdges } ?? instances.first)?.value.willBeginDragging()
	}

	func reset() {
		let previousDelegate = delegate
		delegate = nil
		alwaysBounceVertical = edges.contains(.top) || edges.contains(.bottom)
		alwaysBounceHorizontal = edges.contains(.trailing) || edges.contains(.leading)
		let ratio = CGSize(
			width: edges.contains(.horizontal) ? 3 : edges.isDisjoint(with: .horizontal) ? 1 : 2,
			height: edges.contains(.vertical) ? 3 : edges.isDisjoint(with: .vertical) ? 1 : 2
		)
		contentConstraints.forEach { $0.isActive = false }
		contentConstraints = [
			content.widthAnchor.constraint(equalTo: widthAnchor, multiplier: ratio.width),
			content.heightAnchor.constraint(equalTo: heightAnchor, multiplier: ratio.height),
		]
		contentConstraints.forEach { $0.isActive = true }
		content.frame.size = CGSize(width: frame.width * ratio.width, height: frame.height * ratio.height)
		contentOffset = initialOffset
		delegate = previousDelegate
		visibleContainer.transform = CGAffineTransform(translationX: contentOffset.x, y: contentOffset.y)
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		guard frame.size != lastLayoutSize else { return }
		lastLayoutSize = frame.size
		reset()
	}

	override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		instances.contains { $0.value.shouldBegin(gestureRecognizer) }
			&& super.gestureRecognizerShouldBegin(gestureRecognizer)
	}
}
