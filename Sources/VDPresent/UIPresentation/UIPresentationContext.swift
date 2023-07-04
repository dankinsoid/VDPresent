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
        public var direction: TransitionDirection {
            to.last.map { !from.contains($0) } ?? false
                ? .insertion
                : .removal
        }
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
    
    var all: [UIViewController] {
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
        viewControllers.top.contains(viewController)
    }
    
    var isSecondController: Bool {
        viewControllers.second.contains(viewController)
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

extension UIPresentation.Context.Controllers {
    
    var changing: [UIViewController] {
        direction == .insertion ? toInsert : toRemove
    }
    
    var remaining: [UIViewController] {
        to.filter(from.contains)
    }
    
    var top: [UIViewController] {
        direction == .insertion
        ? Array(to.suffix(1))
        : Array(from.suffix(1))
    }
    
    var second: [UIViewController] {
        direction == .insertion
        ? Array(from.suffix(1))
        : Array(to.suffix(1))
    }
}
