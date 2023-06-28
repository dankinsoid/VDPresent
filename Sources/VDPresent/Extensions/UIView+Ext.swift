import UIKit

protocol Constraintable {

	var asUIView: UIView? { get }
	var leadingAnchor: NSLayoutXAxisAnchor { get }
	var trailingAnchor: NSLayoutXAxisAnchor { get }
	var topAnchor: NSLayoutYAxisAnchor { get }
	var bottomAnchor: NSLayoutYAxisAnchor { get }
}

extension UIView: Constraintable {

	var asUIView: UIView? { self }
}

extension UILayoutGuide: Constraintable {

	var asUIView: UIView? { owningView }
}

extension UIView {
    
    var allSubviews: [UIView] {
        subviews + subviews.flatMap(\.allSubviews)
    }
    
    func update(frame: CGRect) {
        bounds.size = frame.size
        center = CGPoint(
            x: frame.origin.x + bounds.width / 2.0,
            y: frame.origin.y + bounds.height / 2.0
        )
    }
}

extension Constraintable {

	@discardableResult
	func pinEdges(
		_ edges: NSDirectionalRectEdge = .all,
		to view: Constraintable,
		padding: CGFloat = 0,
		priority: UILayoutPriority = .required
	) -> [NSLayoutConstraint] {
		asUIView?.translatesAutoresizingMaskIntoConstraints = false
		var array: [NSLayoutConstraint] = []
		if edges.contains(.leading) {
			array.append(leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding))
		}
		if edges.contains(.trailing) {
			array.append(trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding))
		}
		if edges.contains(.top) {
			array.append(topAnchor.constraint(equalTo: view.topAnchor, constant: padding))
		}
		if edges.contains(.bottom) {
			array.append(bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding))
		}
		array.forEach {
			$0.priority = priority
		}
		NSLayoutConstraint.activate(array)
		return array
	}
}
