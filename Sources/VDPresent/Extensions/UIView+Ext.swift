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
        relation: NSLayoutConstraint.Relation = .equal,
		priority: UILayoutPriority = .required
	) -> [NSLayoutConstraint] {
		asUIView?.translatesAutoresizingMaskIntoConstraints = false
		var array: [NSLayoutConstraint] = []
		if edges.contains(.leading) {
            switch relation {
            case .lessThanOrEqual:
                array.append(leadingAnchor.constraint(lessThanOrEqualTo: view.leadingAnchor, constant: padding))
            case .equal:
                array.append(leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding))
            case .greaterThanOrEqual:
                array.append(leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: padding))
            @unknown default:
                break
            }
		}
		if edges.contains(.trailing) {
            switch relation {
            case .lessThanOrEqual:
                array.append(trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor, constant: -padding))
            case .equal:
                array.append(trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding))
            case .greaterThanOrEqual:
                array.append(trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -padding))
            @unknown default:
                break
            }
		}
		if edges.contains(.top) {
            switch relation {
            case .lessThanOrEqual:
                array.append(topAnchor.constraint(lessThanOrEqualTo: view.topAnchor, constant: padding))
            case .equal:
                array.append(topAnchor.constraint(equalTo: view.topAnchor, constant: padding))
            case .greaterThanOrEqual:
                array.append(topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: padding))
            @unknown default:
                break
            }
		}
		if edges.contains(.bottom) {
            switch relation {
            case .lessThanOrEqual:
                array.append(bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor, constant: -padding))
            case .equal:
                array.append(bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding))
            case .greaterThanOrEqual:
                array.append(bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -padding))
            @unknown default:
                break
            }
		}
		array.forEach {
			$0.priority = priority
		}
		NSLayoutConstraint.activate(array)
		return array
	}
}
