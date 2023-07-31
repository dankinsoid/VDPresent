import SwiftUI

extension UIPresentation.Transition {
    
    public static func uiViewAnimate(
        prepare: @escaping (UIPresentation.Context) -> Void = { _ in },
        animation: @escaping (UIPresentation.Context) -> Void,
        completion: @escaping (UIPresentation.Context, Bool) -> Void = { _, _ in }
    ) -> UIPresentation.Transition {
        UIPresentation.Transition { context in
            prepare(context)
        } animate: { context, update in
            let animate: () -> Void = {
                update(.begin)
                animation(context)
            }
            let complete: (Bool) -> Void = { completed in
                update(.end(completed: completed))
            }
            
            if context.animated {
                if context.isInteractive {
                    let animator = context.animator ?? Animator()
                    context.animator = animator
                    animator.addAnimations(animate)
                    animator.addCompletion { position in
                        complete(position == .end)
                        context.animator?.finishAnimation(at: position == .end ? .end : .start)
                        context.animator = nil
                        context.animatorDidContinue = false
                        context.animatorDidStart = false
                    }
                    update(
                        .prepareInteractive { state in
                            switch state {
                            case .begin:
                                if !context.animatorDidStart {
                                    context.animatorDidStart = true
                                    animator.startAnimation()
                                    animator.pauseAnimation()
                                }
                                
                            case let .change(progress):
                                if animator.fractionComplete != progress.value {
                                    animator.fractionComplete = progress.value
                                }
                                
                            case let .end(completed, duration):
                                if !context.animatorDidContinue {
                                    context.animatorDidContinue = true
                                    animator.isReversed = !completed
                                    animator.continueAnimation(duration: duration)
                                }
                            }
                        }
                    )
                    
                } else {
                    UIView.animate(with: context.animation, animate, completion: complete)
                }
            } else {
                animate()
                complete(true)
            }
        } completion: { context, completed in
            completion(context, completed)
        }
    }
}

private extension UIPresentation.Context {
    
    var animator: Animator? {
        get { cache[\.animator] ?? nil }
        nonmutating set { cache[\.animator] = newValue }
    }
    
    var animatorDidContinue: Bool {
        get { cache[\.animatorDidContinue] ?? false }
        nonmutating set { cache[\.animatorDidContinue] = newValue }
    }
    
    var animatorDidStart: Bool {
        get { cache[\.animatorDidStart] ?? false }
        nonmutating set { cache[\.animatorDidStart] = newValue }
    }
}
