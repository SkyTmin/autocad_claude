# CLAUDE.md — Конституция проекта

> Контракт между Шамилем (геодезист-камеральщик) и любой AI.
> Прочитай полностью. Если AI — сначала §6 «Ритуал», потом работа.

---

## ⚡ РАБОЧАЯ ВЕТКА

**Ветка: `claude/autocad-knowledge-hyVpn`** · Репо: `skytmin/autocad_claude`

Запущен на другой ветке? Немедленно:
```
git fetch origin claude/autocad-knowledge-hyVpn
git checkout claude/autocad-knowledge-hyVpn
```
`main` — только для слияний.

---

## 1. Проект

AutoLISP + Python/.NET для автоматизации чертежей Civil 3D (сваи, монолит, дороги).
Пользователь — Шамиль, не программист. Критерий успеха — экономия времени на чертежах.
Детали: `docs/vision.md` · Технология: `docs/decisions/0001-hybrid-autolisp-dotnet.md`

---

## 2. Старт каждой сессии — читать в этом порядке

1. `CLAUDE.md` (этот файл)
2. `.claude/skills/skill-integrator/integration-map.md` — куда что класть
3. `status/HANDOFF.md` — где остановились
4. `status/ISSUES.md` — блокеры
5. Если работаем над фичей → её `specs/<feature>.md`

---

## 3. Жёсткие правила (Hard Rules)

Нарушение = брак. Всегда, без исключений.

**R1 · Нет тихому упрощению.**
Хочешь срезать scope → `AskUserQuestion`, не молча.

**R2 · Нет placeholder-коду.**
TODO без записи в `status/ISSUES.md` запрещено. Заглушки и пустые функции — запрещены.

**R3 · Нет поверхностным фиксам.**
Баг → root cause → фикс. `try/except` без обработки, `--no-verify`, бипасы тестов — запрещены.

**R4 · Нет выбору без обоснования.**
Архитектурное решение → ADR в `docs/decisions/`. Без ADR альтернативный путь не выбирается.

**R5 · Нет коду по догадкам.**
Сначала читай `samples/` и `src/lisp/`. Нет данных → спроси Шамиля, не выдумывай.

**R6 · Нет "готово" без проверки.**
Не проверено в Civil 3D → пиши явно: *"Код написан, не проверен — нужен ручной запуск."*

---

## 4. Сценарии → что делать

| Сценарий | Действие |
|---|---|
| Начинаю новую задачу | Проверь DoR → `docs/workflow.md` |
| Пишу AutoLISP / код | Читай `docs/conventions.md` + `samples/` |
| Незнакомый геодезический термин | `docs/glossary.md` |
| Завершаю задачу | Прогони DoD → `docs/workflow.md` |
| Архитектурное решение | Создай ADR → `docs/decisions/README.md` |
| Конец сессии | Обнови `status/HANDOFF.md` |
| Нашёл баг или блокер | Запиши в `status/ISSUES.md` |
| Что планируем дальше | `status/ROADMAP.md` + `status/BACKLOG.md` |
| Неясность / развилка / срезать scope | `AskUserQuestion` — не гадай (R1) |
| Запускаю существующий скилл | Сначала `/skill-integrator` (режим A) |
| Добавляю новый скилл в проект | `/skill-integrator` (режим B) |
| Хочу сэкономить токены | `/caveman` |

---

## 5. Языковые конвенции

| Что | Язык / правило |
|---|---|
| Документация (`*.md`) | русский |
| Идентификаторы кода | латиница (`load-csv-points`) |
| Сообщения пользователю | русский |
| Комментарии в коде | русский, ПОЧЕМУ а не ЧТО |
| Имена слоёв в DWG | ГОСТ/СПДС → `docs/conventions.md` |

---

## 6. Карта проекта

```
CLAUDE.md   ← ты здесь         docs/workflow.md     ← процесс: DoD, DoR, SDD-цикл
AGENTS.md   зеркало AI          docs/conventions.md  ← ГОСТ, стиль кода
README.md   для людей           docs/glossary.md     ← геодезические термины
                                docs/decisions/      ← ADR (архитектурные решения)

specs/      ⭐ спецификации фич  status/HANDOFF.md    ⭐ контекст сессии
src/lisp/   AutoLISP-команды    status/PROGRESS.md   ← changelog
samples/    реальные данные     status/ISSUES.md     ← баги / блокеры
                                status/ROADMAP.md    ← план
                                status/QUALITY.md    ← KPI

.claude/settings.local.json          ← allowlist (единственный конфиг)
.claude/skills/skill-integrator/     ← карта интеграции скиллов
.claude/skills/caveman/              ← сжатые ответы, экономия токенов
```

---

## 7. Ритуал старта AI-сессии

**Первая фраза** в начале любой новой сессии:

> "Прочитал CLAUDE.md, понял правила. Иду в `status/HANDOFF.md`."
