# Три группы транзишенов для каждого контроллера

## Модель 1 — по группам транзишенов

Для каждого контроллера в стеке:

```
⓪ Сброс (reset)
   Все view сбрасываются в identity/layout-позицию.
   Нужно чтобы:
   - recessTransition читал правильные target frames
   - beforeTransition захватывал чистое identity-состояние
   Выполняется один раз ДО prepare всех контроллеров.

Затем собираются три группы транзишенов, каждая со своим direction:

combined = [
    ① recessTransition от контроллеров, которые БЫЛИ выше, а теперь НЕТ
       direction: .removal(0...1)
       (эти контроллеры уходят — их recess effect снимается, даже если они все еще в стеке но уже сзади)

    ② own contentTransition
       direction: ownDirection(0...1) или .insertion(1...1) если контроллер и был и будет в стеке
       (собственная анимация появления/ухода)

    ③ recessTransition от контроллеров, которые БУДУТ выше
       direction: .insertion(0...1) или .insertion(1...1) если контроллер и раньше был выше
]
```

## Модель 2 — old/new пары

Универсальная формула: для каждого транзишен-эффекта составляем пару
(снятие старого + применение нового). Если транзишен не изменился —
стейты совпадают, анимации нет.

```
⓪ Сброс (reset)
   Все view сбрасываются в identity/layout-позицию.

Для каждого контроллера V хранится массив слотов:

struct TransitionSlot {
    key: SlotKey                    // сопоставление old↔new
    old: UITransition<UIView>?      // из предыдущего состояния стека (nil если не было)
    new: UITransition<UIView>?      // из нового состояния стека (nil если не будет)
}

enum SlotKey: Hashable {
    case content                    // собственный contentTransition
    case recess(controllerID)       // recess от конкретного контроллера
}

Слоты хранятся отдельно. Для анимации собирается combined:

combined = slots.flatMap { slot in
    var parts: [UITransition] = []
    if let old = slot.old {
        parts.append(old.reversed)          // .removal(0→1) — снятие
    }
    if let new = slot.new {
        parts.append(new)                   // .insertion(0→1) — применение
    }
    return parts
}

Когда old == nil — только применение нового (появление эффекта).
Когда new == nil — только снятие старого (уход эффекта).
Когда оба есть — переход от старого стейта к новому.
Когда оба nil — слот не создаётся.
```

### Порядок слотов

Recess-эффекты чейнятся (выход предыдущего = вход следующего).
Порядок влияет на результат если два recess меняют одно свойство.

```
old-порядок: снизу вверх от V (depth=1 первый, depth=2 второй, ...)
new-порядок: снизу вверх от V (depth=1 первый, depth=2 второй, ...)

В combined:
  1. old-слоты в старом порядке (reversed, removal) — снятие
  2. content slot
  3. new-слоты в новом порядке (insertion) — применение
```

### Как работает чейнинг (combined по keypath)

```
prepare (progress=0):
  old.removal(0)   → old_state   (начало = identity из beforeTransition)
  new.insertion(0)  → old_state   (начало = old_state, progress=0 → pass-through)
  итого: old_state

animate (progress=1):
  old.removal(1)   → identity    (progress=1 → снято)
  new.insertion(1)  → new_state   (начало = identity, progress=1 → применено)
  итого: new_state

→ анимация от old_state к new_state
```

### Частные случаи

| Ситуация | old | new | prepare | animate | Результат |
|----------|-----|-----|---------|---------|-----------|
| X появляется выше | .identity | recess(X) | identity | recessed | анимация: identity → recessed ✅ |
| X уходит сверху | recess(X) | .identity | recessed | identity | анимация: recessed → identity ✅ |
| X остаётся, depth не менялся | recess(d) | recess(d) | recessed(d) | recessed(d) | нет анимации ✅ |
| X остаётся, depth изменился | recess(d1) | recess(d2) | recessed(d1) | recessed(d2) | плавный переход ✅ |
| V появляется | .identity | content | identity | on-screen | анимация появления ✅ |
| V уходит | content | .identity | on-screen | identity→off | анимация ухода ✅ |
| V остаётся | content | content | on-screen | on-screen | нет анимации ✅ |