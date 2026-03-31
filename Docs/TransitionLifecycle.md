# Transition Lifecycle — какие транзишены к какой view применяются и когда

## Участники

- **View A** — контроллер, уходящий назад (или удаляемый)
- **View B** — контроллер, появляющийся сверху (top)
- **contentTransition** — анимация самого контроллера (slide, fade, move)
- **recessTransition** — анимация "уступания" для view, оказавшихся позади

---

## Временная шкала: Insertion (push / present)

```
Стек: [A] → [A, B]     direction = .insertion
                        B = arriving (isChangingController, top)
                        A = remaining (behind)
```

```
Время ──────────────────────────────────────────────────────►

        ① Reset          ② Prepare              ③ Animate              ④ Completion
        ───────          ─────────              ─────────              ────────────

View B: reset to        build combined:         update combined:       cleanup
        identity        ┌─────────────────┐     progress =             (remove bg
        (layout pos.)   │ contentTransition│     .insertion(1)          if departing)
                        │ (e.g. .move)    │
                        └─────────────────┘     → view B скользит
                        beforeTransition()         на место (identity)
                        update(.insertion(0))
                        → view B за экраном

View A: reset to        build combined:         update combined:
        identity        ┌─────────────────┐     progress =
        (layout pos.)   │ .identity       │     .insertion(1)
                        │ (frozen behind) │
                        │ + recessTransition│    → view A уезжает
                        │   от B (reversed)│       назад (recessed)
                        └─────────────────┘
                        beforeTransition()
                        update(.insertion(0))
                        → view A на месте
                           (recess ещё 0)
```

### Что собирается для каждой view (buildTransitions)

| View | Slot 1: own contentTransition | Slot 2+: recessTransition от контроллеров выше |
|------|-------------------------------|-----------------------------------------------|
| **B** (top, arriving) | `contentTransition(ctx)` — e.g. `.move(edge: .trailing)` | нет контроллеров выше → пусто |
| **A** (behind, frozen) | `.identity` (isBehindFrozen = true) | `B.recessTransition(depth=1, ctx).reversed` |

### Progress по фазам

| Фаза | Progress | `.progress` (CGFloat) | Смысл |
|------|----------|----------------------|-------|
| Prepare | `.insertion(0)` | 0.0 | "ещё не вставлен" — B за экраном, A на месте |
| Animate | `.insertion(1)` | 1.0 | "полностью вставлен" — B на месте, A recessed |

---

## Временная шкала: Removal (pop / dismiss)

```
Стек: [A, B] → [A]     direction = .removal
                        B = departing (isChangingController, top)
                        A = remaining (behind)
```

```
Время ──────────────────────────────────────────────────────►

        ① Reset          ② Prepare              ③ Animate              ④ Completion
        ───────          ─────────              ─────────              ────────────

View B: reset to        build combined:         update combined:       removeFromParent
        identity        ┌─────────────────┐     progress =             container removed
        (on screen)     │ contentTransition│     .insertion(0)
                        │ (e.g. .move)    │
                        └─────────────────┘     → view B уезжает
                        beforeTransition()         за экран
                        update(.insertion(1))
                        → view B на месте
                           (fully inserted)

View A: reset to        build combined:         update combined:
        identity        ┌─────────────────┐     progress =
        (layout pos.)   │ .identity       │     .insertion(0)
                        │ (frozen behind) │
                        │ + recessTransition│    → view A возвращается
                        │   от B (reversed)│       на место (identity)
                        └─────────────────┘
                        beforeTransition()
                        update(.insertion(1))
                        → view A recessed
                           (recess = 1)
```

### Progress по фазам (removal)

| Фаза | Progress | `.progress` (CGFloat) | Смысл |
|------|----------|----------------------|-------|
| Prepare | `.insertion(1)` | 1.0 | "всё ещё вставлен" — B на месте, A recessed |
| Animate | `.insertion(0)` | 0.0 | "удалён" — B за экраном, A на месте |

---

## Композиция транзишенов (combined)

Для каждой view собирается массив `[UITransition<UIView>]`:

```
transitions = [
    own contentTransition (или .identity если frozen),
    recessTransition от VC[myIndex+1]  (depth=1),
    recessTransition от VC[myIndex+2]  (depth=2),
    ...  // до barrier или конца стека
]
```

Они объединяются через `UITransition.combined()`:
- Если два транзишена меняют **разные** свойства → просто складываются
- Если два транзишена меняют **одно** свойство (например, оба `.transform`) → **чейнятся**: выход первого = вход второго

```
combined = UITransition.combined(transitions)
combined.beforeTransition(view)   // захватить identity
combined.update(progress, view)   // применить прогресс
```

---

## Пример: Navigation Push (A → B)

```
contentTransition = .move(edge: .trailing)        // B едет справа
recessTransition  = .move(edge: .leading, 0.3)    // A едет влево на 30%
backEffectBarrier = true                           // не накапливать
```

### Insertion: push B

```
                    Prepare                         Animate
                    progress = .insertion(0)         progress = .insertion(1)
                    ┌──────────────────────┐         ┌──────────────────────┐
                    │                      │         │                      │
View B (top):       │  [B за экраном ►]    │  ──►    │  [B на месте]        │
  content = move    │  x = +screenWidth    │         │  x = 0               │
                    │                      │         │                      │
View A (behind):    │  [A на месте]        │  ──►    │  [◄ A смещён -30%]   │
  recess = move 0.3 │  x = 0              │         │  x = -30% width      │
                    │                      │         │                      │
                    └──────────────────────┘         └──────────────────────┘
```

### Removal: pop B

```
                    Prepare                         Animate
                    progress = .insertion(1)         progress = .insertion(0)
                    ┌──────────────────────┐         ┌──────────────────────┐
                    │                      │         │                      │
View B (top):       │  [B на месте]        │  ──►    │  [B за экраном ►]    │
  content = move    │  x = 0               │         │  x = +screenWidth    │
                    │                      │         │                      │
View A (behind):    │  [◄ A смещён -30%]   │  ──►    │  [A на месте]        │
  recess = move 0.3 │  x = -30% width     │         │  x = 0               │
                    │                      │         │                      │
                    └──────────────────────┘         └──────────────────────┘
```

---

## Пример: Sheet Presentation (A → B)

```
contentTransition  = .move(edge: .bottom)    // B едет снизу
recessTransition   = .scale(0.92)            // A уменьшается
overCurrentContext  = true                    // A остаётся видимым
backEffectBarrier  = false
```

```
                    Prepare                         Animate
                    ┌──────────────────────┐         ┌──────────────────────┐
                    │                      │         │  ┌──────────────┐    │
View B (sheet):     │  [B под экраном ▼]   │  ──►    │  │ B (sheet)    │    │
  content = move    │  y = +screenHeight   │         │  │              │    │
                    │                      │         │  └──────────────┘    │
View A (behind):    │  [A на месте]        │  ──►    │  [ A (scale 0.92) ]  │
  recess = scale    │  scale = 1.0         │         │  scale = 0.92        │
                    │                      │         │                      │
                    └──────────────────────┘         └──────────────────────┘
```

---

## Глубокий стек: 3+ контроллера

```
Стек: [A, B, C]    push D (insertion)
Visible: [A, B, C, D]   (зависит от overCurrentContext)
```

| View | own transition | recess от D (depth=1) | recess от C (depth=2) | recess от B (depth=3) |
|------|---------------|----------------------|----------------------|----------------------|
| **D** (top) | contentTransition | — | — | — |
| **C** | .identity (frozen) | ✅ D.recess(1) | — | — |
| **B** | .identity (frozen) | ✅ D.recess(2) | ✅ C.recess(1) | — |
| **A** | .identity (frozen) | ✅ D.recess(3) | ✅ C.recess(2) | ✅ B.recess(1) |

**С barrier** (navigation): каждый контроллер ставит `backEffectBarrier = true`, поэтому:

| View | own transition | recess effects |
|------|---------------|----------------|
| **D** (top) | contentTransition | — |
| **C** | .identity (frozen) | D.recess(1) только ← barrier на D |
| **B** | .identity (frozen) | C.recess(1) только ← barrier на C |
| **A** | .identity (frozen) | B.recess(1) только ← barrier на B |

---

## Фазы подробно (код)

### ① Reset (UIStackController, до prepare)
```swift
for controller in allVisible {
    ctx.viewTransitions.reset(view: ctx.view)    // setInitialState → undo
    ctx.viewTransitions.removeAll()              // clear combined
}
```
Все view возвращаются в layout-позицию. Это нужно чтобы recessTransition
читал правильные target frames из layout, а не из анимированных позиций.

### ② Prepare (DefaultTransition.base → buildTransitions)
```swift
// Для каждой visible view:
transitions = [own contentTransition или .identity] + [recess effects from above]
var merged = UITransition.combined(transitions)
merged.beforeTransition(view: view)       // захватить identity-значения
merged.update(progress: prepareProgress, view: view)  // применить начальное состояние
context.viewTransitions.combined = merged  // сохранить для animate
```

### ③ Animate (AnimationDriver → UIView.animate)
```swift
UIView.animate(with: animation) {
    for (context, transition) in items {
        // Вызывает transition.animation(context):
        context.viewTransitions.combined?.update(progress: animateProgress, view: view)
    }
}
```
UIKit интерполирует от prepare-state к animate-state через Core Animation.

### ④ Completion
```swift
for controller in visibleControllers {
    transition.completion(context, isCompleted)
}
// Если !isCompleted (cancelled): откат стека
// Если isCompleted: removeFromParent для departing VCs
```

---

## Interactive transitions

При интерактивном переходе (жест):

```
AnimationDriver использует UIViewPropertyAnimator вместо UIView.animate

                    ┌─ begin ─────────┐
                    │ startAnimation() │
                    │ pauseAnimation() │
                    └─────────────────┘
                           │
                    ┌─ change(progress) ──────────┐
                    │ animator.fractionComplete = p │   ← жест обновляет
                    └─────────────────────────────┘
                           │
                    ┌─ end(completed, duration) ──┐
                    │ animator.isReversed = !done  │
                    │ animator.continueAnimation() │
                    └─────────────────────────────┘
```

Progress 0..1 отображается на ту же combined transition.

---

## isBehindFrozen — кто анимирует свой contentTransition

| behindBehavior | Top VC animates? | Behind VC animates contentTransition? |
|---------------|-------------------|--------------------------------------|
| `.freeze` | ✅ | ❌ — только recess effects |
| `.animate` | ✅ | ✅ — departing/arriving behind VCs тоже |
| `.freezeMatching` | ✅ | ❌ если тот же transitionID, ✅ если другой |

Frozen = `transitions[0]` будет `.identity`, а не `contentTransition`.
Recess effects всё равно применяются.

---

## Departing back views — `.constant(at:)`

Когда view A уходит из стека И находится позади B:

```swift
if isDeparting {
    backTransition = backTransition.constant(at: .insertion(1))
}
```

Это значит recess effect от B на A **не анимируется** — он зафиксирован
на `.insertion(1)` (полный recess). Иначе при removal A стал бы
возвращаться из recessed-состояния, хотя сам при этом тоже уезжает.
