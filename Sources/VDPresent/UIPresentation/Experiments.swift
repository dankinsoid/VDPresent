import SwiftUI

public protocol ControllerTransitionTransform {

  func didLayoutBeforeAppear(context: UIPresentation.Context)
  func willAppear(context: UIPresentation.Context)
  func isAppearing(context: UIPresentation.Context, progress: Double)
  func didAppear(context: UIPresentation.Context)
  func willDisappear(context: UIPresentation.Context)
  func isDisappearing(context: UIPresentation.Context, progress: Double)
  func didDisappear(context: UIPresentation.Context)
}

struct SheetTransform: ControllerTransitionTransform {                                                                                                                      

    let edge: Edge                                                                                                                                                          
    let cornerRadius: CGFloat                                                                                                                                             
                                                                                                                                                                                                                                                                                                                                 
    func didLayoutBeforeAppear(context: UIPresentation.Context) {}                                                                                                          
                                                                                                                                                       
    // Вызывается после layout, до анимации — ставим вью в начальную позицию                                                                                                
    func willAppear(context: UIPresentation.Context) {                                                                                                                      
      let view = context.view                                                                                                                                             
      view.clipsToBounds = true                                                                                                                                         
      view.layer.cornerRadius = cornerRadius                                                                                                                              
      view.layer.maskedCorners = .edge(edge.opposite)
      // Сдвигаем за экран по нужному ребру                                                                                                                               
      view.transform = offscreenTransform(view: view, edge: edge)                                                                                                         
    }                                                                                                                                                                       
                                                                                                                                                                              
    // Анимируем до финальной позиции                                                                                                                                       
    func isAppearing(context: UIPresentation.Context, progress: Double) {
      let view = context.view                                                                                                                                             
//      view.transform = .identity.interpolated(                                                                                                                            
//        to: offscreenTransform(view: view, edge: edge),
//        progress: 1 - progress                                                                                                                                          
//      )                                                                                                                                                                 
    }

    func didAppear(context: UIPresentation.Context) {}                                                                                                                                                                   
                                                                                                                                                                         
    // Перед уходом — вью уже на месте, ничего не делаем                                                                                                                    
    func willDisappear(context: UIPresentation.Context) {}
                                                                                                                                                                              
    // Анимируем уход — обратно за экран                                                                                                                                   
    func isDisappearing(context: UIPresentation.Context, progress: Double) {
      let view = context.view                                                                                                                                             
//      view.transform = .identity.interpolated(                                                                                                                          
//        to: offscreenTransform(view: view, edge: edge),
//        progress: progress                                                                                                                                              
//      )
    }

    func didDisappear(context: UIPresentation.Context) {}                

    private func offscreenTransform(view: UIView, edge: Edge) -> CGAffineTransform {                                                                                        
      switch edge {                                                                                                                                                     
        case .bottom: return CGAffineTransform(translationX: 0, y: view.bounds.height)
        case .top:    return CGAffineTransform(translationX: 0, y: -view.bounds.height)                                                                                     
        case .leading:  return CGAffineTransform(translationX: -view.bounds.width, y: 0)                                                                                    
        case .trailing: return CGAffineTransform(translationX: view.bounds.width, y: 0)                                                                                     
      }                                                                                                                                                                   
    }                                                                                                                                                                     
}

/// Обёртка, добавляющая dimming background к любому трансформу.
struct WithDimmingBackground: ControllerTransitionTransform {

    let inner: ControllerTransitionTransform
    let color: UIColor
    let placement: BackgroundPlacement

    func didLayoutBeforeAppear(context: UIPresentation.Context) {
        inner.didLayoutBeforeAppear(context: context)
    }

    func willAppear(context: UIPresentation.Context) {
        inner.willAppear(context: context)
        let bg = getOrCreateBackground(context: context)
        bg.alpha = 0
    }

    func isAppearing(context: UIPresentation.Context, progress: Double) {
        inner.isAppearing(context: context, progress: progress)
        context.backgroundView?.alpha = CGFloat(progress)
    }

    func didAppear(context: UIPresentation.Context) {
        inner.didAppear(context: context)
    }

    func willDisappear(context: UIPresentation.Context) {
        inner.willDisappear(context: context)
    }

    func isDisappearing(context: UIPresentation.Context, progress: Double) {
        inner.isDisappearing(context: context, progress: progress)
        context.backgroundView?.alpha = 1 - CGFloat(progress)
    }

    func didDisappear(context: UIPresentation.Context) {
        // Убираем background при полном уходе
        context.backgroundView?.removeFromSuperview()
        context.backgroundView = nil
        inner.didDisappear(context: context)
    }

    private func getOrCreateBackground(context: UIPresentation.Context) -> UIView {
        if let existing = context.backgroundView { return existing }
        let bg = UIView()
        bg.backgroundColor = color
        bg.isUserInteractionEnabled = false
        context.backgroundView = bg

        switch placement {
        case .global:
            context.container.insertSubview(bg, at: 0, layout: .fill)
        case .behindController:
            // Вставляем в view контроллера, который прямо под нами
            if let i = context.viewControllers.to.firstIndex(of: context.viewController), i > 0 {
                let belowVC = context.viewControllers.to[i - 1]
                context.for(belowVC).view.addSubview(bg, layout: .fill)
            }
        }
        return bg
    }
}

func hmhm() {
	// move(to: .bottom)
	// will appear: transform = dy = height
	// is appearing: transform = dy = height * (1 - progress)
	// is disappearing: transform = dy = height * progress
}
