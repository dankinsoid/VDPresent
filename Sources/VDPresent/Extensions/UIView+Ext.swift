import UIKit

extension UILayoutGuide {
    
    func pinEdges(to guid: UILayoutGuide, padding: CGFloat = 0) {
        owningView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
        	leadingAnchor.constraint(equalTo: guid.leadingAnchor, constant: padding),
          trailingAnchor.constraint(equalTo: guid.trailingAnchor, constant: -padding),
          topAnchor.constraint(equalTo: guid.topAnchor, constant: padding),
          bottomAnchor.constraint(equalTo: guid.bottomAnchor, constant: -padding),
        ])
    }
}

extension UIView {
    
    func pinEdges(to view: UIView, padding: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding),
        ])
    }
    
    func pinEdges(to guid: UILayoutGuide, padding: CGFloat = 0) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: guid.leadingAnchor, constant: padding),
            trailingAnchor.constraint(equalTo: guid.trailingAnchor, constant: -padding),
            topAnchor.constraint(equalTo: guid.topAnchor, constant: padding),
            bottomAnchor.constraint(equalTo: guid.bottomAnchor, constant: -padding),
        ])
    }
}
