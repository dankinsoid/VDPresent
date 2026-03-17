import UIKit

final class UIStackControllerView: UIView {

	var containers: [UIStackControllerCanvas] = [] {
		didSet {
			for item in oldValue {
				if !containers.contains(item) {
					item.removeFromSuperview()
				}
			}
			for container in containers {
				addSubview(container)
				if !oldValue.contains(container) {
					container.pinEdges(to: self)
				}
			}
			layout()
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		layout()
	}

	private func layout() {
		for container in containers {
			container.update(frame: bounds)
		}
	}
}
