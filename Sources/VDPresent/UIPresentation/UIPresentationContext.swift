import UIKit

public extension UIPresentation {
    
    struct Context {
        
        public var viewController: UIViewController {
            _controller ?? UIViewController()
        }
        public var view: UIStackViewWrapper {
            view(for: viewController)
        }
        public var container: UIStackControllerContainer {
            container(for: viewController)
        }
        public let animated: Bool
        public let isInteractive: Bool
        public let cache: Cache
        public let animation: UIKitAnimation
        public let viewControllers: Controllers
        public let direction: TransitionDirection
        
        public var environment: UIPresentation.Environment {
            _environment(viewController)
        }
        
        private weak var _controller: UIViewController?
        private let views: (UIViewController) -> UIStackViewWrapper
        private let _container: (UIViewController) -> UIStackControllerContainer
        private let _environment: (UIViewController) -> UIPresentation.Environment
        private let _updateStatusBar: (UIStatusBarStyle, UIStatusBarAnimation) -> Void
        
        public init(
            direction: TransitionDirection,
            controller: UIViewController,
            container: @escaping (UIViewController) -> UIStackControllerContainer,
            fromViewControllers: [UIViewController],
            toViewControllers: [UIViewController],
            views: @escaping (UIViewController) -> UIStackViewWrapper,
            animated: Bool,
            animation: UIKitAnimation,
            isInteractive: Bool,
            cache: Cache,
            updateStatusBar: @escaping (UIStatusBarStyle, UIStatusBarAnimation) -> Void,
            environment: @escaping (UIViewController) -> UIPresentation.Environment
        ) {
            self.direction = direction
            self._controller = controller
            self._container = container
            self.viewControllers = Controllers(
                fromViewControllers: fromViewControllers,
                toViewControllers: toViewControllers
            )
            self.views = views
            self.animated = animated
            self.isInteractive = isInteractive
            self.cache = cache
            self._updateStatusBar = updateStatusBar
            self._environment = environment
            self.animation = animation
        }
        
        public func environment(for controller: UIViewController) -> UIPresentation.Environment {
            _environment(controller)
        }
        
        public func container(for controller: UIViewController) -> UIStackControllerContainer {
            _container(controller)
        }
        
        public func updateStatusBar(style: UIStatusBarStyle, animation: UIStatusBarAnimation = .fade) {
            _updateStatusBar(style, animation)
        }
        
        public func view(for controller: UIViewController) -> UIStackViewWrapper {
            views(controller)
        }
        
        public func `for`(controller: UIViewController) -> Self {
            var result = self
            result._controller = controller
            return result
        }
    }
}

extension UIPresentation.Context {
    
    public struct Controllers {
        
        public var from: [UIViewController] { _fromViewControllers.compactMap(\.value) }
        public var to: [UIViewController] { _toViewControllers.compactMap(\.value) }
        private let _fromViewControllers: [Weak<UIViewController>]
        private let _toViewControllers: [Weak<UIViewController>]
        
        public init(
            fromViewControllers: [UIViewController],
            toViewControllers: [UIViewController]
        ) {
            self._fromViewControllers = fromViewControllers.map { Weak($0) }
            self._toViewControllers = toViewControllers.map { Weak($0) }
        }
        
        public subscript(_ key: UITransitionContextViewControllerKey) -> [UIViewController] {
            switch key {
            case .from: return from
            case .to: return to
            default: return []
            }
        }
        
    }
}

public extension UIPresentation.Context.Controllers {
    
    var toRemove: [UIViewController] {
        from.filter { !to.contains($0) }
    }
    
    var toInsert: [UIViewController] {
        to.filter { !from.contains($0) }
    }
    
    func all(_ direction: TransitionDirection) -> [UIViewController] {
        guard !from.isEmpty else { return to }
        guard !to.isEmpty else { return from }
        let prefix = from.dropLast().filter { !to.contains($0) } + to.dropLast()
        let suffix = from.suffix(1) + to.suffix(1).filter { $0 !== from.last }
        return direction == .insertion
        ? prefix + suffix
        : prefix + suffix.reversed()
    }
    
    var isTopTheSame: Bool {
        from.last === to.last
    }
}

public extension UIPresentation.Context {
    
    final class Cache {
        
        private var values: [PartialKeyPath<UIPresentation.Context>: Any] = [:]
        
        public subscript<T>(_ keyPath: ReferenceWritableKeyPath<UIPresentation.Context, T>) -> T? {
            get { values[keyPath] as? T }
            set { values[keyPath] = newValue }
        }
        
        public init() {}
    }
}

extension UIPresentation.Context {
    
    var isChangingController: Bool {
        !viewControllers.to.contains(viewController) || !viewControllers.from.contains(viewController)
    }
    
    var isRemainingController: Bool {
        !isChangingController
    }
    
    var isTopController: Bool {
        topViewControllers.contains(viewController)
    }
    
    var isSecondController: Bool {
        secondViewControllers.contains(viewController)
    }
    
    func needHide(_ key: UITransitionContextViewControllerKey) -> Bool {
        let all = viewControllers[key]
        guard let j = all.firstIndex(of: viewController) else { return false }
        for (index, vc) in all.enumerated().reversed() {
            if let i = environment(for: vc).contextTransparencyDeep, index - i > j {
                return true
            }
        }
        return false
    }
    
    var needAnimate: Bool {
        isTopController && !viewControllers.isTopTheSame || isChangingController && !needHide(.to)
    }
}

extension UIPresentation.Context {
    
    var changingViewControllers: [UIViewController] {
        direction == .insertion ? viewControllers.toInsert : viewControllers.toRemove
    }
    
    var topViewControllers: [UIViewController] {
        direction == .insertion
        ? Array(viewControllers.to.suffix(1))
        : Array(viewControllers.from.suffix(1))
    }
    
    var secondViewControllers: [UIViewController] {
        direction == .insertion
        ? Array(viewControllers.from.suffix(1))
        : Array(viewControllers.to.suffix(1))
    }
    
    var allViewControllers: [UIViewController] {
        guard !viewControllers.from.isEmpty else { return viewControllers.to }
        guard !viewControllers.to.isEmpty else { return viewControllers.from }
        let prefix = viewControllers.from.dropLast().filter { !viewControllers.to.contains($0) } + viewControllers.to.dropLast()
        let suffix = viewControllers.from.suffix(1) + viewControllers.to.suffix(1).filter { $0 !== viewControllers.from.last }
        return direction == .insertion
        ? prefix + suffix
        : prefix + suffix.reversed()
    }
}

extension UIPresentation.Context.Controllers {
    
    var remaining: [UIViewController] {
        to.filter(from.contains)
    }
}
