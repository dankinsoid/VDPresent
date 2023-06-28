import UIKit

public extension UIPresentation.Interactivity {

	static var swipe: UIPresentation.Interactivity {
		swipe(to: .bottom)
	}

	static func swipe(
		to edges: NSDirectionalRectEdge,
		startFromEdge: Bool = false
	) -> UIPresentation.Interactivity {
		UIPresentation.Interactivity { context, observer in
            context.viewControllersToInsert.forEach { controller in
                let view = context.container(for: controller)
                let tapRecognizer = TransitionContainerTapRecognizer()
                view.addGestureRecognizer(tapRecognizer)
                tapRecognizer.onTap = { [weak controller] in
                    controller?.hide()
                }
                
                let swipeRecognizer = SwipeGestureRecognizer()
                swipeRecognizer.edges = edges
                swipeRecognizer.startFromEdges = startFromEdge
                swipeRecognizer.update = observer
                swipeRecognizer.target = context.view(for: controller)
                view.addGestureRecognizer(swipeRecognizer)
            }
		}
	}
}

private final class SwipeViewObserver: SwipeViewDelegate {

	let observer: (UIPresentation.State) -> Void
	var wasBegun = false

	init(observer: @escaping (UIPresentation.State) -> Void) {
		self.observer = observer
	}

	func begin() {
		guard !wasBegun else { return }
		wasBegun = true
		observer(.begin)
	}

	func shouldBegin() -> Bool {
		!wasBegun
	}

	func update(_ percent: CGFloat) {
		observer(.change(.removal(percent)))
	}

	func cancel() {
		wasBegun = false
		observer(.end(completed: false))
	}

	func finish() {
		wasBegun = false
		observer(.end(completed: true))
	}
}
