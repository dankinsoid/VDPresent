import SwiftUI

public extension UIPresentation.Interactivity {

	static var swipe: UIPresentation.Interactivity {
		swipe(to: .bottom)
	}
    
    @_disfavoredOverload
    static func swipe(
        to edge: Edge
    ) -> UIPresentation.Interactivity {
        .swipe(to: NSDirectionalRectEdge(edge))
    }
    
    static func swipe(
        to edges: NSDirectionalRectEdge
    ) -> UIPresentation.Interactivity {
        swipe(configuration: .default(edges: edges))
    }
    
	static func swipe(
        configuration: SwipeConfiguration
	) -> UIPresentation.Interactivity {
		UIPresentation.Interactivity { context, observer in
            let controller = context.viewController
            let view = context.container
            let tapRec = view.gestureRecognizers?.compactMap { $0 as? TransitionContainerTapRecognizer }.first
            let swipeRec = view.gestureRecognizers?.compactMap { $0 as? SwipeGestureRecognizer }.first
            let tapRecognizer = tapRec ?? TransitionContainerTapRecognizer()
            if tapRec == nil {
                view.addGestureRecognizer(tapRecognizer)
            }
            tapRecognizer.isEnabled = true
            tapRecognizer.onTap = { [weak controller] in
                controller?.hide()
            }
            
            let swipeRecognizer = swipeRec ?? SwipeGestureRecognizer()
            swipeRecognizer.isEnabled = true
            swipeRecognizer.edges = configuration.edges
            swipeRecognizer.startFromEdges = context.environment.swipeFromEdge
            swipeRecognizer.fullDuration = context.animation.duration
            swipeRecognizer.shouldStart = { [weak controller] edge in
                guard let controller else { return false }
                return configuration.shouldStart(for: context, from: controller, to: edge)
            }
            swipeRecognizer.update = { [weak controller] percent, edge in
                guard let controller else { return .prevent }
                return observer(configuration.context(for: context, from: controller, to: edge), percent)
            }
            swipeRecognizer.target = context.view
            if swipeRec == nil {
                view.addGestureRecognizer(swipeRecognizer)
            }
        } uninstaller: { context in
            context.container.gestureRecognizers?
                .compactMap { $0 as? TransitionContainerTapRecognizer }
                .forEach(context.container.removeGestureRecognizer)
            context.container.gestureRecognizers?
                .compactMap { $0 as? SwipeGestureRecognizer }
                .forEach(context.container.removeGestureRecognizer)
        }
	}
    
    struct SwipeConfiguration {
        
        public let edges: NSDirectionalRectEdge
        private let _shouldStart: (UIPresentation.Context, UIViewController, Edge) -> Bool
        private let _moveToEdgeContext: (UIPresentation.Context, UIViewController, Edge) -> UIPresentation.Context
        
        public init(
            edges: NSDirectionalRectEdge,
            shouldStart: @escaping (UIPresentation.Context, UIViewController, Edge) -> Bool,
            moveToEdgeContext: @escaping (UIPresentation.Context, UIViewController, Edge) -> UIPresentation.Context
        ) {
            self.edges = edges
            self._shouldStart = shouldStart
            self._moveToEdgeContext = moveToEdgeContext
        }
        
        public func shouldStart(
            for context: UIPresentation.Context,
            from controller: UIViewController,
            to edge: Edge
        ) -> Bool {
            _shouldStart(context, controller, edge)
        }
        
        public func context(
            for context: UIPresentation.Context,
            from controller: UIViewController,
            to edge: Edge
        ) -> UIPresentation.Context {
            _moveToEdgeContext(context, controller, edge)
        }
        
        public static func `default`(
            edges: NSDirectionalRectEdge
        ) -> SwipeConfiguration {
            SwipeConfiguration(edges: edges) { context, controller, edge in
                guard
                    edges.contains(NSDirectionalRectEdge(edge)),
                    let i = context.viewControllers.to.firstIndex(where: controller.isDescendant)
                else {
                    return false
                }
                return i > 0
            } moveToEdgeContext: { context, controller, edge in
                UIPresentation.Context(
                    direction: .removal,
                    controller: controller,
                    container: { context.for($0).container },
                    fromViewControllers: context.viewControllers.to,
                    toViewControllers: Array(
                        context.viewControllers.from.prefix(
                            upTo: context.viewControllers.to.firstIndex(where: controller.isDescendant)
                                ?? context.viewControllers.to.count - 1
                        )
                    ),
                    views: { context.for($0).view },
                    animated: true,
                    animation: context.animation,
                    isInteractive: true,
                    cache: context.cache,
                    updateStatusBar: context.updateStatusBar,
                    environment: {
                        context.for($0).environment.with(\.currentSwipeEdge, edge)
                    }
                )
            }
        }
    }
}

public extension UIPresentation.Environment {
    
    var swipeFromEdge: Bool {
        get { self[\.swipeFromEdge] ?? false }
        set { self[\.swipeFromEdge] = newValue }
    }
    
    var currentSwipeEdge: Edge? {
        get { self[\.currentSwipeEdge] ?? nil }
        set { self[\.currentSwipeEdge] = newValue }
    }
}
