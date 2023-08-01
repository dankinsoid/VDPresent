import UIKit

enum D {
    
    case stack([UIViewController])
    case array([UIViewController], selectedIndex: Int)
    case lazy(UIStackViewDataSource)
}

struct UIStackViewDataSource {
    
    let controllerBefore: (UIViewController) -> UIViewController?
    let controllerAfter: (UIViewController) -> UIViewController?
    let count: Int?
    var current: UIViewController?
    
    init(
        controllerBefore: @escaping (UIViewController) -> UIViewController?,
        controllerAfter: @escaping (UIViewController) -> UIViewController?,
        count: Int?,
        current: UIViewController?
    ) {
        self.controllerBefore = controllerBefore
        self.controllerAfter = controllerAfter
        self.count = count
        self.current = current
    }
    
    init(stack: [UIViewController]) {
        self.init(
            controllerBefore: {
                guard let index = stack.firstIndex(of: $0) else { return nil }
                return index > 0 ? stack[index - 1] : nil
            },
            controllerAfter: {
                guard let index = stack.firstIndex(of: $0) else { return nil }
                return index + 1 < stack.count ? stack[index + 1] : nil
            },
            count: stack.count,
            current: stack.last
        )
    }
}
