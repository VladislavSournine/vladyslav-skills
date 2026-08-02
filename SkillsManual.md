# Skills Manual

Короткий практичний гайд по встановлених скілах. Формат: **що робить → коли викликати**.

---

## Передумови

- **Claude Code** — встановлений
- **Superpowers plugin** — потрібен для `add-feature`, `fix-bug`, `ingest`, `pre-release-check`, `write-docs`
- **MemPalace MCP server** 🧠 — потрібен для 8 скілів нижче. Без нього вони впадуть на першому ж виклику `mempalace_*` тулзи.

### Скіли що вимагають MemPalace 🧠

`add-feature` · `fix-bug` · `ingest` · `pre-release-check` · `compact-save` · `qsave` · `memory-lint`

Інші скіли (`orchestrate`, `init-project`, `attach-project`, `write-docs`, `swiftui-pro`, `smoke-test-skills`) працюють без MemPalace.

---

## За завданням

### Точка входу (якщо не знаєш, який скіл потрібен)

- **`/vladyslav:orchestrate`** — класифікує запит і сам маршрутизує в потрібний скіл: баг → `fix-bug`, нова поведінка → `add-feature`, проект без `docs/architecture/` → `ingest`, реліз → `pre-release-check`. Маршрут озвучується одним рядком перед запуском — можна перебити.
- Питання про автономію (Manual/Auto) задається **один раз** і передається вниз у `add-feature` — повторно там не питається.
- **Тривіальне не маршрутизується**: одруківка, бамп версії, однорядкова правка, git-операція робляться інлайн без скіла. Обгортати одруківку в повний пайплайн — порушення «драбини».

### Старт проекту з нуля

- **`/vladyslav:init-project`** — створює повну Claude-friendly структуру (`docs/`, `.claude/`, `CLAUDE.md`, agents). Детектить стек (Python/Go/Flutter/Swift/Kotlin), генерує skeleton документації.
- Після init'а запусти `/superpowers:brainstorming` щоб обговорити MVP, потім `/vladyslav:add-feature` для першої фічі.

### Приєднання Claude до існуючого проекту

- **`/vladyslav:attach-project`** — додає Claude-структуру до існуючого коду **не ламаючи** файли. Auto-detect стеків.
- **`/vladyslav:ingest`** 🧠 — єдиний прохід: сканує код, заповнює `docs/architecture/system.md`, `api.md`, `db-schema.sql`, і записує ключові архітектурні рішення в MemPalace wing проекту. Після цього майбутні сесії не сканують репу наново.

### Додавання фічі

- **`/vladyslav:add-feature`** 🧠 — повний цикл: `self-heal shell (якщо нема) → brainstorm → contract → plan → parallel execution (tests + code) → auto-gate (tests + review + security) → merge → docs update`.
- Автоматично діють: Blast Radius Rule (мінімальні зміни), Contract-First (контракт до коду), Mandatory Code Review (чекліст).
- **Два режими** (скіл питає на старті):
  - **Manual** — stop-and-tell після кожної фази. Для нетипових/ризикових фіч.
  - **Auto** — після апрува контракту і плану все виконується без зупинок (parallel agents → auto-gate → commit → merge to dev). Апрув повертається тільки на merge-to-main або на guard rail.
- **Guard rails (auto-mode автоматично зупиняє + питає):**
  - > 2 файли зачеплені поза планом
  - Рефактор файла що був позначений "read-only reference"
  - Контракт змінився під час виконання (hash mismatch)
  - Auto-gate blocker: впав тест / HIGH-severity review / security finding
- **Auto-gate (перед кожним комітом в auto-mode, без апрува):** тести → code review agent → owasp-security. Блокує коміт при помилках.

### Дизайн-система (щоб новий екран не виглядав як чужий проект)

> Скіли `design-sync` / `design-page` прибрано у v5.0.0 (не використовувались). Дисципліна лишається правилом, не скілом:

- **Глобальне правило "Design System Discipline"** (в `~/.claude/CLAUDE.md`) — перед будь-якою UI-задачею я зобов'язаний:
  1. Прочитати `docs/design/system.md` як контракт
  2. Просканувати asset catalog за існуючими токенами
  3. **НЕ винаходити** нові кольори / іконки / шрифти / padding — тільки reuse
  4. Якщо потрібен новий токен — СТОП, питаю дозволу, реєструю в `docs/design/system.md`
- **Template:** порожній канон живе в `templates/DesignSystem.md` — `init-project` пише його автоматично для UI-проектів (swift/flutter/kotlin/web), скіпає для backend-only.
- **`apple-hig-expert`** (з `c-level-skills@claude-code-skills`) — iOS HIG аудит, викликається окремо за потреби.

### Product Discovery (перед кодом)

> Скіли `discover` / `discover-apple-check` прибрано у v5.0.0. Discovery робиться вручну або разовим промптом: заповни секції 6–10 у `docs/product/start-project.md` (конкуренти — WebSearch, монетизація/оцінка — обговорення в сесії). Для iOS rejection-risk перевірки викликай скіл `apple-appstore-reviewer` напряму.

### Документування проекту

- **`/vladyslav:write-docs`** — один скіл з меню: user stories / test plan + QA / README + onboarding + deployment (або all).
- **`/vladyslav:ingest`** 🧠 — оновлює архітектурні доки (`docs/architecture/*`) і MemPalace wing одночасно.

### Тестування

- **`/vladyslav:write-docs`** (режим tests) — генерує `docs/testing/test-plan.md` і `docs/testing/manual-qa.md`.
- **`/superpowers:test-driven-development`** — реально пише тести (test-first). Викликається автоматично всередині `add-feature` і `fix-bug`.
- **`/vladyslav:pre-release-check`** 🧠 — фінальна верифікація перед релізом (тести, docs, rollback, translations). **iOS only:** запускає submission-phase Apple App Store review — hard gate, BLOCKER/HIGH робить весь чек FAIL. Cross-reference з `docs/product/apple-review.md` (pre-dev audit) + свіжі rejection patterns зі `swift-calories` wing. Output → `docs/release/apple-review-submission.md`.

### Перевірка секуріті

- **`/owasp-security`** — OWASP-style аудит на injection, XSS, secrets, auth, CSRF.
- **`/pr-review-toolkit:silent-failure-hunter`** — шукає мовчазні catch-блоки і fallback-и що приховують помилки.
- **`/pr-review-toolkit:code-reviewer`** — загальне code review.
- **Автоматично:** секція "Mandatory Code Review" в `~/.claude/CLAUDE.md` запускає security checklist в кінці кожної задачі.

### Фікс багу

- **`/vladyslav:fix-bug`** 🧠 — повний цикл: `self-heal shell (якщо нема) → worktree → systematic-debugging → triage (план якщо нетривіально) → regression test → minimal fix → code review → merge → docs + MemPalace problem record`.
- Автоматично використовує `superpowers:systematic-debugging` (не стрибає до висновків).
- Автоматично діє Blast Radius Rule — якщо потрібен більший рефакторинг, спитає дозволу.

### Юзер сторі

- **`/vladyslav:write-docs`** (режим stories) — генерує `docs/product/user-stories.md` у форматі `As [role], I can [action], so that [benefit]` з acceptance criteria і статусами (Done / Partial / Not started).
- Джерело: реальний код + PRD + існуючі сторі. Корисно коли QA потрібен registry реалізованих фіч.

### Session Continuity

- **`/vladyslav:compact-save`** 🧠 — знімок поточного стану задачі в MemPalace (`compact-save` drawer). Автоматично викликається через `PreCompact` hook перед компресією контексту — не потрібно нічого робити вручну. Зберігає: поточна задача, змінені файли, останнє рішення, наступний крок.

- **`/vladyslav:qsave`** 🧠 — єдиний вхід для knowledge records (замінив `save` у v5.0.0): нуль питань, типи `decision` · `preference` · `problem` · `milestone`, явний контент і wing перекривають деривацію ("qsave to ops: ...").

Після компресії або на початку сесії глобальне правило **Compact-Save Continuity** (`~/.claude/CLAUDE.md`) автоматично знаходить останній compact-save для активного wing і відновлює контекст — без `/unstash`, без ручних кроків.

---

## Робочі сценарії

### Сценарій A: Новий проект з нуля

```
cd ~/NewProject
/vladyslav:init-project                    # структура + CLAUDE.md + docs/
                                           # + пише docs/product/start-project.md зі шаблона
# (заповни секції 1-10 в start-project.md вручну — discovery-скіли прибрано у v5.0.0)
/vladyslav:ingest                          # (опційно) сканує код + seeds MemPalace
                                           # корисно після кількох фіч для оновлення architecture docs
/vladyslav:add-feature                     # повний цикл першої фічі (auto mode рекомендовано)
# ... наступні фічі через /vladyslav:add-feature ...
/vladyslav:write-docs                      # stories / tests / project docs (меню або all)
/vladyslav:pre-release-check               # фінал
```

MemPalace wing створиться автоматично — після кожної задачі глобальне правило "MemPalace strict use" записує рішення в wing проекту.

**Старий (низькорівневий) flow** — якщо хочеш руками кермувати кожним кроком без `add-feature` обгортки:
```
/superpowers:brainstorming → /superpowers:writing-plans →
/superpowers:dispatching-parallel-agents → /superpowers:requesting-code-review →
/superpowers:finishing-a-development-branch
```

MemPalace wing створиться автоматично — після кожної задачі глобальне правило "MemPalace strict use" записує рішення в wing проекту.

### Сценарій B: Існуючий проект — підтягнути найкращі архітектурні рішення

```
cd ~/ExistingRepo
/vladyslav:attach-project            # Claude-структура без перезапису файлів
/vladyslav:ingest                    # сканує код → docs/architecture/* + ключові рішення в MemPalace wing
/vladyslav:write-docs                # stories / tests / project docs
```

**Ефект:** кожна наступна сесія починається з `mempalace_search wing=<project>` замість сканування коду. Нові фічі (`/vladyslav:add-feature`) автоматично використовують контекст і глобальні правила.

### Сценарій C: Критичний баг

```
cd ~/Project
/vladyslav:fix-bug                   # worktree + діагностика + regression test + fix
```

Blast Radius Rule застосовується автоматично — якщо фікс вимагає більшого рефакторингу, спитаю дозволу перед розширенням scope.

### Сценарій D: Підготовка до релізу

```
cd ~/Project
/vladyslav:write-docs                # test plan / README / deployment (меню)
/vladyslav:pre-release-check         # фінальна верифікація
```

### Сценарій E: Рефакторинг (без зміни поведінки)

Рефакторинг — особливий випадок: **тести мають бути НАПИСАНІ ДО початку**, щоб підтвердити що поведінка не змінилась. Blast Radius Rule тут критичний — легко почати з "одного класу" і закінчити переписаним модулем.

```
cd ~/Project
/superpowers:using-git-worktrees     # ізольована гілка refactor/<scope>
mempalace_search wing=<project>      # перевірити чи є попередні рішення по цьому коду
/superpowers:brainstorming           # ЧИ потрібен рефакторинг? Що конкретно болить?
/vladyslav:write-docs                # якщо тести відсутні — спочатку написати characterization tests (режим tests)
/superpowers:test-driven-development # покриття того що буде рефакториться
/superpowers:writing-plans           # atomic кроки, кожен залишає код working
/superpowers:dispatching-parallel-agents  # якщо кроки незалежні
/pr-review-toolkit:code-simplifier   # для cleanup після рефакторингу
/superpowers:requesting-code-review  # обов'язково, рефакторинг = високий ризик регресій
/superpowers:finishing-a-development-branch
```

**Ключові правила для рефакторингу:**
- **Ніколи не міксуй рефакторинг з новою поведінкою** — окремі коміти / окремі PR.
- **Тести мають проходити після кожного коміту** — rollback point на кожному кроці.
- **Blast Radius** — якщо "один клас" перетворюється в "переписування модуля", STOP і спитай чи це все ще виправдано.
- **Записати рішення в MemPalace ПІСЛЯ** — майбутні сесії мають знати чому було зроблено саме так.

### Сценарій F: Міграція бази даних

Міграція бази — найвищий ризик в будь-якому workflow: незворотні зміни, downtime, цілісність даних. Contract-First тут обов'язковий — схема це контракт.

```
cd ~/Project
/superpowers:using-git-worktrees     # ізоляція гілки migration/<description>
mempalace_search wing=<project>      # попередні міграції, gotchas, rollback patterns
/superpowers:brainstorming           # схема + стратегія (online/offline, backfill, shadow writes)
# Contract-First: write the schema change as explicit contract
/superpowers:writing-plans           # має включати rollback plan і data validation step
/superpowers:test-driven-development # міграційні тести: up, down, data integrity, concurrent writes
/vladyslav:add-feature               # якщо міграція пов'язана з новою фічею
/owasp-security                      # перевірка на injection в нових queries
/pr-review-toolkit:code-reviewer     # code review з фокусом на data safety
/vladyslav:pre-release-check         # ОБОВ'ЯЗКОВО перед релізом міграцій
/superpowers:finishing-a-development-branch
```

**Ключові правила для міграцій:**
- **Zero-downtime за замовчуванням** — експансивні зміни (додати колонку nullable, backfill, зробити not-null) замість руйнівних.
- **Завжди writable rollback** — `down` міграція має бути перевірена на реальних даних, не тільки на schema.
- **Shadow writes / dual-read** для критичних змін — міграція даних через період "обидві колонки живі".
- **Тести на concurrent writes** — міграція під навантаженням ≠ міграція на dev.
- **Backup перед запуском** — очевидно, але записати в плані явно.
- **Записати повний migration record в MemPalace** як `problem` + `decision`: що мігрували, чому такий підхід, які виникли gotchas, скільки займе rollback.

---

## Глобальні правила (з `~/.claude/CLAUDE.md`, завжди діють)

1. **Blast Radius Rule** — найменша оправдана зміна. Більший рефакторинг = STOP і питаю дозволу.
2. **MemPalace strict use** — шукаю в MemPalace ПЕРЕД скануванням коду, записую в MemPalace ПІСЛЯ виконаного.
   - **Path validation (завжди):** після `mempalace_search` перевіряю кожен абсолютний шлях у результатах. Якщо шлях не існує на диску → drawer `[STALE]`, не використовую.
   - **Wing naming:** канонічна назва wing = `basename(pwd)` → lowercase → hyphens → platform prefix. Ніколи не пишу у wing з великими літерами.
3. **Contract-First** — контракт (типи/сигнатури/приклади) перед кодом, тести в паралель з кодом.
4. **Mandatory Code Review** — чекліст перед "done": correctness → security → code smell → minimal change compliance.
5. **LSP over Grep** — для Swift/Python/TS/Kotlin/Lua використовую LSP для пошуку символів, не Grep.
6. **MCP Tool Discipline** — ніколи не читаю `~/.claude/projects/*/tool-results/*.txt` через Bash/Grep. Це внутрішній кеш Claude Code. Для повторного отримання даних — викликаю MCP tool напряму (заблоковано hook-ом автоматично).

---

## Що працює автоматично (без виклику)

Це відповідь на питання "чому все вимагає апрува?". Ось що вже працює **фонoм**:

| Механізм | Тригер | Що робить |
|---|---|---|
| **Pre-commit hook** (`~/.claude/hooks/pre-commit-review.sh`) | Будь-який `git commit` з Bash tool | Друкує Mandatory Code Review чекліст як нагадування (non-blocking). Вимикається через `NO_COMMIT_REVIEW=1`. |
| **Tool-results block hook** (`~/.claude/hooks/block-tool-results-grep.sh`) | Будь-який Bash що чіпає `~/.claude/projects/*/tool-results/` | **Блокує** з поясненням. Примусовий — обходу немає. |
| **MemPalace session-end indexing** | Кінець сесії | Індексує сесію в MemPalace (wing detection + room classification). |
| **Mandatory Code Review чекліст** | Кінець будь-якої задачі | Я сам проходжу корректність → секюріті → код-смел → мінімальність. Прописано в `~/.claude/CLAUDE.md`. |
| **Blast Radius Rule** | Перед будь-яким edit | Я сам декларую scope і не виходжу за нього без дозволу. |
| **Auto-gate в `add-feature` (auto mode)** | Перед кожним комітом | Тести → code review agent → owasp-security. Блокує коміт при помилках. Апрув не потрібен. |
| **Contract hash baseline в `add-feature` (auto mode)** | Під час виконання плану | Перевіряю що контракт не змінився з моменту апруву. |
| **File-scope guard rails в `add-feature` (auto mode)** | Після кожного batch'а | Перевіряю що агенти не зачепили файли поза планом. |
| **Parallel agents в `add-feature`** | Коли план розбитий на незалежні задачі | Два subagent'и в worktree паралельно пишуть тести і код. |

**Що завжди потребує явного виклику slash-командою** (модель не запускає сама — таке практично через структуру команд + чітко описане у `description` поле):

- `write-docs` — документація (stories / tests / project)
- `owasp-security` (standalone повний аудит — автоматичний тільки в auto-gate)
- `pre-release-check` — фінальна верифікація
- `ingest` — одноразова операція (або після великих рефакторів)
- `fix-bug`, `add-feature` — навмисно explicit, бо запускають повний цикл

Раніше плагін використовував `disable-model-invocation: true` у frontmatter `commands/*.md` для блокування авто-виклику. У сучасних версіях Claude Code це поле блокувало і явні slash-команди (Skill tool refused), тому ми його прибрали в v2.3.1 — модель полагається на `description:` для вирішення коли НЕ викликати скіл, а сам користувач все одно може викликати через `/vladyslav:<name>`.

---

## Коли апрув обов'язковий (auto mode в `add-feature`)

1. Опис фічі (Step 2)
2. Brainstorm output (Step 4)
3. Contract (Step 4.5)
4. Plan (Step 5)
5. Merge в `main` (Step 8 кінець)
6. Будь-який guard rail trigger
7. Фінальний `/vladyslav:pre-release-check`

Між 4 і 5 — все виконується без зупинок: parallel agents → auto-gate (tests/review/security) → commit → наступний batch → ... → merge в `dev`.

---

## Довідка по зовнішніх бібліотеках (LSP / Context7 / WebFetch)

Три різних джерела знань — кожне вирішує свою задачу. Використовую **перший ліворуч що відповідає питанню**:

| Задача | Інструмент | Чому саме цей |
|---|---|---|
| Де визначена функція/клас/символ у **моєму** коді? | **LSP** (`getDefinition`) | Миттєво, точно, без текстового шуму |
| Хто викликає цю функцію? | **LSP** (`getReferences`) | Розуміє scope, не матчить рядки і коментарі |
| Який тип/сигнатура? | **LSP** (`getHover`) | Повна type info, дешево по токенах |
| Є компіл-помилки? | **LSP** (`getDiagnostics`) | Без запуску білда |
| Як правильно викликати функцію з **зовнішньої** бібліотеки (React, SwiftUI, FastAPI, Ktor)? | **Context7** | Актуальна документація навіть якщо моє training data застаріло |
| Який синтаксис в конкретній версії (Prisma 6, AI SDK v6, Vercel config)? | **Context7** | Version-специфічний контент |
| Apple DocC / Human Interface Guidelines / WWDC tutorials | **WebFetch** на `developer.apple.com/...` | Context7 тонкий по цьому контенту |
| Android developer guides (Material 3, Jetpack best practices) | **WebFetch** на `developer.android.com/...` | Те саме — бібліотечні API в Context7 є, довгі гайди частково |
| Рішення які я вже приймав в цьому проекті | **MemPalace** (`mempalace_search wing=<project>`) | Внутрішня пам'ять, не зовнішні доки |
| Загальні блоги, StackOverflow, обговорення | **WebSearch** | Остання лінія — коли решта не допомагає |

**LSP встановлено для:** Swift, Python, TypeScript/JavaScript, Kotlin, Lua. Для інших мов (Dart, Shell) — Grep.

**Context7 вже увімкнений** (`context7@claude-plugins-official`) — працює через MCP tools `resolve-library-id` + `query-docs`. Не плутай з vladyslav-скілами.

**Правило бренда:** якщо я збираюсь Grep по всій репі щоб "зрозуміти як працює X" — STOP. Якщо X — мій код → LSP. Якщо X — зовнішня бібліотека → Context7. Якщо X — рішення минулого → MemPalace.

---

## Допоміжні скіли (викликаються автоматично з `vladyslav:*`)

| Superpowers | Для чого |
|---|---|
| `brainstorming` | Структуровані ідеї перед плануванням |
| `writing-plans` | Розбивка на bite-sized задачі |
| `dispatching-parallel-agents` | Паралельне виконання (тести + код) |
| `subagent-driven-development` | Послідовне виконання в одній сесії |
| `test-driven-development` | Test-first розробка |
| `systematic-debugging` | Debug без гіпотез навмання |
| `requesting-code-review` | Запит ревю |
| `receiving-code-review` | Обробка фідбеку з верифікацією |
| `finishing-a-development-branch` | Merge / PR / cleanup |
| `using-git-worktrees` | Ізоляція роботи |
| `verification-before-completion` | Не казати "готово" без доказів |

---

## Повний список vladyslav скілів

| Скіл | Модель | Коли |
|---|---|---|
| `init-project` | Engineer | Новий проект з нуля (+ пише `start-project.md` зі шаблона) |
| `attach-project` | Engineer | Приєднання Claude до існуючого коду |
| `ingest` | Architect 🧠 | Єдиний прохід: architecture docs + MemPalace seed. Замінює `analyze-project` + `seed-mempalace`. |
| `orchestrate` | Architect | Точка входу: класифікує запит, маршрутизує в потрібний скіл, тривіальне робить інлайн |
| `add-feature` | Architect | Повний цикл нової фічі (manual / auto mode) |
| `fix-bug` | Architect | Повний цикл фіксу багу |
| `write-docs` | Engineer | Документація з меню: user stories / test plan + QA / README + deployment (або all) |
| `pre-release-check` | Engineer | Фінальна верифікація перед релізом |
| `swiftui-pro` | Engineer | Ревю SwiftUI/Swift коду: deprecated API, accessibility, HIG, Swift concurrency (iOS 26 / Swift 6.2). Автоматично викликається в `add-feature` Step 6.5 для iOS проектів. |
| `compact-save` | Engineer 🧠 | Знімок task state в MemPalace (auto перед compaction) |
| `qsave` | Engineer 🧠 | Швидкий запис у MemPalace без питань (все з розмови) |
| `smoke-test-skills` | Engineer | Batch-валідація всіх скілів плагіна (статичні перевірки) |
| `memory-lint` | Engineer 🧠 | Health-check MemPalace: дрейф wing-ів, split-brain, недокументовані кімнати, мертві шляхи. Тільки звіт + регенерація wing-індексу |

**Architect** (5 скілів: `orchestrate`, `ingest`, `add-feature`, `fix-bug`, `swiftui-pro`) — інтерактивно в Opus main. Внутрішні Agent dispatches позначені `model="sonnet"` (executor) або `model="opus"` (synthesis).
**Engineer (light) — bash-driven** (`init-project`, `attach-project`, `pre-release-check`, `smoke-test-skills`) — pre-flight Q&A в Opus, потім bash-скрипт, потім summary.
**Engineer (light) — Opus inline** (`write-docs`, `compact-save`, `qsave`, `memory-lint`) — LLM-генерація без dispatch.

---

## Інтегровані зовнішні скіли

### `vladyslav:swiftui-pro` — Paul Hudson's SwiftUI Agent Skill

**Джерело:** [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) (MIT)
**Розміщення:** `~/.vladyslav-skills/skills/swiftui-pro/`

Перевіряє SwiftUI/Swift код за 9 категоріями:

| Reference | Що перевіряє |
|---|---|
| `api.md` | Deprecated API → сучасний еквівалент (iOS 26 / Swift 6.2) |
| `views.md` | Структура view, composition, анімації |
| `data.md` | Data flow, `@Observable`, property wrappers |
| `navigation.md` | NavigationStack, alerts, sheets |
| `design.md` | Flexible layout, ContentUnavailableView, системні компоненти |
| `accessibility.md` | Dynamic Type, VoiceOver, Reduce Motion |
| `performance.md` | AnyView, lazy stacks, `task()` vs `onAppear()` |
| `swift.md` | Modern Swift, concurrency, актори |
| `hygiene.md` | Keychain, LocalizedStrings, SwiftLint |
| `ios-hig.md` | Apple HIG compact checklist (layout, nav, a11y, color, components) |

**Автоматичний виклик:** `add-feature` Step 6.5 — якщо diff містить `.swift` файли.
**Ручний виклик:** `/vladyslav:swiftui-pro` для окремого ревю.

---

### iOS HIG Rules (ehmo/platform-design-skills)

**Джерело:** [ehmo/platform-design-skills](https://github.com/ehmo/platform-design-skills) (MIT)
**Розміщення:** вбудовано в `skills/swiftui-pro/references/ios-hig.md`

HIG правила по 10 категоріях (CRITICAL/HIGH/MEDIUM) з Correct/Incorrect прикладами Swift коду. Перевіряються на code review: `ios-hig.md` входить у ревю SwiftUI коду скілом `swiftui-pro`.

---

### Android Agent Skills (defer до появи Android проекту)

**Джерело:** [krutikJain/android-agent-skills](https://github.com/krutikJain/android-agent-skills) (MIT)
**Статус:** задокументовано, не інтегровано — немає Android проектів

34 скіли для Android/Compose розробки:

| Категорія | Скіли |
|---|---|
| Compose | compose-foundations, compose-state-effects, compose-performance, compose-accessibility, compose-xml-interoperability |
| Архітектура | architecture-clean, state-management, modularization, navigation-deeplinks |
| DI & Storage | di-hilt, room-database, local-persistence-datastore |
| Мережа | networking-retrofit-okhttp, serialization-offline-sync |
| Тести | testing-unit, testing-ui |
| Дизайн | material3-design-system, mobile-frontend-design |
| CI/CD | ci-cd-release-playstore, gradle-build-logic, gradle-build-performance |
| Інше | kotlin-core, coroutines-flow, security-best-practices, performance-observability, workmanager-notifications |

**Коли інтегрувати:** при старті першого Android проекту — клонувати репо, створити `skills/android-pro/` аналогічно `swiftui-pro`, зареєструвати команди.

---

## Приклади повних флоу

### Приклад 1: Новий проект — "chess-duel" (iOS шахи з ШІ-тренером)

```
$ mkdir ~/chess-duel && cd ~/chess-duel && claude
```

**Крок 1 — структура (Engineer light — bash-driven, v3.0+).**
```
> /vladyslav:init-project
```
Я питаю режим — ти: "interactive". Pre-flight Q&A в Opus main, потім `scripts/modules/core.sh` за ~1 секунду пише голий AI shell (`CLAUDE.md`, `.claude/settings.json`, `.gitignore`, `.remember/`), далі opt-in меню дозволяє вибрати docs / backend-infra / agents — кожен модуль в `scripts/modules/` виконується тільки якщо вибраний. Report: "Заповни секції 1–4 у `docs/product/start-project.md`".

**Крок 2 — заповнюєш руками секції 1–4** в `docs/product/start-project.md`:
- §1 Ідея: "iOS шахи з ШІ що пояснює кожен твій хід українською"
- §2 Проблема: "Новачки не розуміють чому хід поганий"
- §3 Аудиторія: "1200–1800 ELO, українськомовні"
- §4 MVP scope: "Дошка + ходи + один простий бот + post-move пояснення"

**Крок 3 — product research (вручну, за бажанням).** Заповнюєш секції 6–10 у `start-project.md` сам або разовим промптом у сесії (конкуренти через WebSearch, монетизація/оцінка — обговоренням). Для iOS rejection-risk — скіл `apple-appstore-reviewer` напряму.

**Крок 4 — перша фіча (Architect).**
```
> /vladyslav:add-feature
```
Я: "Manual чи Auto mode?" → ти: "Auto". Я: "Яка фіча?" → ти: "Ядро гри: дошка, фігури, move generation, check/checkmate detection, SwiftUI board view".

Я читаю `CLAUDE.md` + `docs/architecture/` + `docs/product/start-project.md`. Запускаю `mempalace_search wing=chess-duel` (перший раз — порожньо). Викликаю `superpowers:brainstorming`.

- **Approval #1** — ти затвердив brainstorm output (board representation = matrix Int8, move gen = pseudo-legal потім legality filter, SwiftUI + Observation)
- **Approval #2** — ти затвердив контракт: `Piece`, `Board`, `Move`, `makeMove()`, `isLegal()`, `isCheckmate()`
- **Approval #3** — ти затвердив план: 6 задач, з файл-листом кожна

**Далі БЕЗ зупинок** (це і є auto mode):
1. Batch 1 (Piece + Board) → launch 2 subagents (tests + code) в worktree → обидва готові → guard rails pass → auto-gate: `swift test` → code review agent → `owasp-security` → commit
2. Batch 2 (move generation) → ... → commit
3. ... (5–15 хвилин без тебе)
4. Merge `feature/core-chess-game` → `dev`

- **Approval #4** — "Merge в main?" — ти: "yes"

Я оновлюю `docs/product/user-stories.md`, `docs/plans/tasks.md`, пишу MemPalace decision record: `[WHAT] chess core, [DECISIONS] matrix board, pseudo-legal gen, [FILES] Sources/Chess/*.swift`. Architect report.

**Крок 5 — наступна сесія, додаємо "Move history panel":**
```
> /vladyslav:add-feature
```
Я на старті автоматично роблю `mempalace_search wing=chess-duel` → знаходжу decision record про board representation → знаю що `Move` вже існує → НЕ винаходжу нові типи. Далі звичайний add-feature flow.

---

### Приклад 2: Приєднання до існуючого проекту — "python-tax"

Проект вже існує, працює, але без Claude-структури.

```
$ cd ~/python-tax && claude
```

**Крок 1 — attach без руйнування коду.**
```
> /vladyslav:attach-project
```
Я детекчу стек (Python/Django 5 + Postgres). Пишу `CLAUDE.md`, створюю `docs/` з порожніми файлами, `.claude/agents/`. НЕ торкаюся коду. Report: "Далі — `/vladyslav:ingest`".

**Крок 2 — ingest: аналіз коду + seed MemPalace (ОДИН РАЗ).**
```
> /vladyslav:ingest
```
Два bash-скрипти збирають JSON (`scan-architecture.sh` + `gather-seed-signals.sh`). Opus синтезує: заповнює `docs/architecture/system.md` (модулі, потоки), `docs/architecture/api.md` (endpoints), `docs/architecture/db-schema.sql`. Паралельно витягує ~10–20 ключових рішень в `wing=python-tax` як `decision` records. **Після цього майбутні сесії не скануть репу наново** — вони будуть робити `mempalace_search wing=python-tax` і отримувати ці рішення миттєво.

**Крок 3 — user stories з реалізованого.**
```
> /vladyslav:write-docs
```
Я читаю код + роутинг + тести, пишу `docs/product/user-stories.md` зі статусами (Done / Partial / Not started).

**Крок 4 — якщо треба product research заднім числом:** заповнюєш секції у `start-project.md` вручну або разовим промптом (див. Приклад 1, Крок 3).

**Крок 5 — нова фіча (як у Прикладі 1).**
```
> /vladyslav:add-feature
```
Тепер весь контекст вже є: CLAUDE.md auto-loaded, MemPalace має архітектурні decisions, юзер сторі відомі. Фіча йде швидше.

---

### Приклад 3: Як виглядає розмова — хто коли викликається

Це розбивка "за лаштунками", щоб ти розумів що автоматично, а що ні.

**На старті сесії (`claude` в директорії проекту):**
- ⚙ SessionStart hook → завантажує Remember (`.remember/`), Vercel-контекст, memory index з `MEMORY.md`
- ⚙ Я бачу CLAUDE.md (глобальний + проектний) як context
- ⚙ MCP сервери підключаються (MemPalace, Context7, Pencil, etc.)
- ❌ Я НЕ роблю mempalace_search автоматично — тільки коли задача потребує

**Ти: "подивись що тут за проект"**
- ✅ Я можу зробити `mempalace_search wing=<project>` (коштує дешево, вартує спробувати)
- ✅ Я читаю `CLAUDE.md`, `docs/architecture/system.md`, `docs/product/prd.md`
- ❌ Я НЕ Grep-аю всю репу — це порушує LSP-over-Grep rule

**Ти: "додай екран налаштувань"** (UI задача в swift-sudoku)
- ✅ Я ПОВИНЕН `mempalace_search wing=swift-sudoku "settings screen"` — раптом вже обговорювали
- ✅ Я ПОВИНЕН прочитати `docs/design/system.md` як контракт (глобальне правило "Design System Discipline") — без нього не починаю UI задачі
- ✅ Якщо якогось токена бракує — зупиняюсь і питаю, не винаходжу
- ✅ Я питаю: "Manual чи Auto mode?" (якщо це через `add-feature`)
- ✅ Всередині add-feature — brainstorm → contract → plan → parallel agents → auto-gate → commit

**Ти: "що ми вирішили про кольори в календарі?"**
- ✅ Я одразу `mempalace_search wing=<project> "кольори календар"`
- ✅ Якщо знаходжу — цитую і перевіряю що воно все ще актуальне в коді
- ❌ Я НЕ перечитую увесь code щоб "згадати" — це втрата часу

**Ти: "запам'ятай що ми вибрали PostgreSQL замість MySQL"**
- ✅ Я явно викликаю `mempalace_check_duplicate` → `mempalace_add_drawer` з room=`decision`
- ✅ Повертаю ID запису

**Ти пишеш код, я роблю git commit:**
- ⚙ Pre-commit hook (`~/.claude/hooks/pre-commit-review.sh`) автоматично друкує Mandatory Code Review чекліст — **без мого виклику, без твого дозволу**
- ⚙ Коміт йде далі (hook non-blocking)

**Кінець сесії:**
- ⚙ SessionEnd hook (`~/.claude/scripts/mempalace-mine-session.sh`) автоматично індексує цю розмову в MemPalace (wing detection + room classification) — **асинхронно, ти можеш закривати термінал**

**Легенда:**
- ⚙ = автоматично, системою, без тебе і без мене
- ✅ = я роблю згідно правил з CLAUDE.md
- ❌ = я НЕ роблю (анти-паттерн)

---

## Helper scripts (`scripts/`, 15 штук)

Детермінована робота винесена в bash-скрипти — скіли передають їм параметри і споживають JSON, замість того щоб LLM писав інструкції типу "тут роби `mkdir`, тут `grep`, тут `git init`". Канонічна довідка живе у `docs/architecture/system.md`; тут — короткий зведений список.

**Discovery / detection (читаємо проект, нічого не пишемо):**

| Скрипт | Що повертає |
|---|---|
| `detect-stack.sh` | JSON з ознаками стеку (ios/python/go/...) |
| `scan-architecture.sh` | Entry points + routes (FastAPI/Flask/Express/Go stdlib) + schema + deps |
| `gather-seed-signals.sh` | Git themes + decision commits + manifests + existing docs |
| `extract-tokens.sh` | Design tokens (colors/typography/icons/spacing) per platform |
| `section-status.sh` | Які секції `start-project.md` уже filled / pending |
| `grep-replace-me.sh` | Quote-safe пошук `REPLACE_ME` / `TBD` placeholders |
| `derive-wing.sh` | Канонічна назва MemPalace wing |

**Scaffolding (створюють файли):**

| Скрипт | Викликає скіл |
|---|---|
| `scripts/modules/core.sh` + `scripts/modules/*.sh` | `init-project` (модульний scaffold: core завжди, решта — opt-in) |
| `attach-project.sh` | `attach-project` (skip-if-exists scaffold у існуючому проекті) |
| `write-stub.sh` | utility для одного doc-stub |
| `init-git-repo.sh` | idempotent `git init` + initial commit |

**Verification / reporting:**

| Скрипт | Викликає скіл |
|---|---|
| `pre-release-checks.sh` | `pre-release-check` (5 cross-platform checks → JSON) |
| `check-plan-scope.sh` | `quality-gate.sh` (scope-делегат для `add-feature` Auto mode) |
| `quality-gate.sh` | `add-feature`, `fix-bug` — per-task "done" gate: тести + гігієна diff + секрети + scope → JSON |
| `changelog-from-git.sh` | `pre-release-check` (draft CHANGELOG з git log) |

Усі скрипти POSIX-portable (macOS + Linux), без python/node залежностей, віддають JSON або машинно-читабельний текст. Більшість завершуються за <1 секунду.

---

*Останнє оновлення: 2026-08-01 (v5.0.0 — orchestrate як точка входу; злиття write-* у write-docs і save у qsave; 12 active skills)*
