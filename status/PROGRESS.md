# Progress — changelog

Краткая история того, что было сделано. Одна строка на пункт.
Формат: `YYYY-MM-DD — [тип] описание`.

---

## 2026-05

- 2026-05-03 — [chore] создан фундамент проекта: CLAUDE.md (Конституция),
  AGENTS.md, README.md, docs/ (vision, glossary, conventions, workflow),
  ADR-0001 (гибрид AutoLISP+Python/.NET), ADR-0002 (Spec-Driven Development),
  специальные папки specs/, status/, src/lisp/, samples/, .claude/
- 2026-05-03 — [sample] добавлена реальная съёмка одной сваи:
  `samples/csv/2026-05-03-pile-sample-01.csv` (11 точек, тахеометр Leica TS10)
- 2026-05-03 — [spec] черновик SPEC-001 «Обработка свай — отклонение между
  нижним и верхним сечениями» (`specs/001-pile-deviation.md`); ожидает
  согласования Шамиля по 5 открытым вопросам

---

## Шаблон

```
- YYYY-MM-DD — [тип] что добавлено/изменено
```

Типы: `feat`, `fix`, `docs`, `refactor`, `chore`, `spec`, `adr`.
