import UIKit

final class UIStackControllerView: UIView {
    
    var containers: [UIStackControllerContainer] = [] {
        didSet {
            oldValue.forEach {
                if !containers.contains($0) {
                    $0.removeFromSuperview()
                }
            }
            containers.forEach {
                addSubview($0)
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
