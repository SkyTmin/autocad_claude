# autocad_claude

Автоматизация рутины камеральной работы геодезиста в **AutoCAD Civil 3D**:
исполнительные съёмки, разбивочные чертежи, монолит/сваи/дороги — строительная геодезия.

**Технология**: гибрид AutoLISP (внутри Civil 3D) + Python/.NET (внешняя обработка).

---

## Если ты AI

Открой и прочти **по порядку**:
1. [`CLAUDE.md`](./CLAUDE.md) — Конституция: правила, Hard Rules, Definition of Done
2. [`status/HANDOFF.md`](./status/HANDOFF.md) — где остановилась прошлая сессия
3. [`status/ROADMAP.md`](./status/ROADMAP.md) — куда движемся

Не пиши ни строчки кода до выполнения этого ритуала.

## Если ты человек

- [`docs/vision.md`](./docs/vision.md) — цель и метрики
- [`docs/workflow.md`](./docs/workflow.md) — как работаем с AI
- [`status/ROADMAP.md`](./status/ROADMAP.md) — текущий план

## Структура

```
docs/      долговечные знания (vision, glossary, conventions, decisions)
specs/     спецификации фич — источник истины
status/    живое состояние (HANDOFF, ROADMAP, PROGRESS, ISSUES, QUALITY)
src/lisp/  AutoLISP-исходники
samples/   реальные примеры данных
```

Подробная карта — в [`CLAUDE.md`](./CLAUDE.md) §9.
