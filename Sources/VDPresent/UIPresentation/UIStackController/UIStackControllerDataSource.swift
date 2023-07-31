import UIKit

public protocol UIStackControllerDataSource {
    
    func nextController(after current: UIViewController?) -> UIViewController?
    func previousController(before current: UIViewController?) -> UIViewController?
}

// 1. One controller (window root)
// 2. Stack (navigation)
// 3. Selected (tabs)
// 4. Lazy (pages)

// current: [UIViewController]
// visibleIndex: Int? ???
