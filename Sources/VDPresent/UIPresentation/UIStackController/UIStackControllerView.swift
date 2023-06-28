import UIKit

final class UIStackControllerView: UIView {
    
    var containers: [UIStackControllerContainerView] = [] {
        didSet {
            oldValue.forEach {
                if !containers.contains($0) {
                    $0.removeFromSuperview()
                }
            }
            containers.forEach {
                addSubview($0)
                $0.translatesAutoresizingMaskIntoConstraints = false
            }
            layout()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layout()
    }
    
    private func layout() {
        containers.forEach {
            $0.update(frame: bounds)
        }
    }
}
