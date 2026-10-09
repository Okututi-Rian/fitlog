# FitLog — Technical Architecture & Design Guide

> "FitLog" is a placeholder name. Rename it whenever you like (Phase 9 covers this).
> This document is written for someone who has **never built a mobile app**. Every concept is explained
> the first time it appears, and every design choice comes with a **"Why"**.
> Put this file in your project at `docs/ARCHITECTURE.md`. Your coding agent will treat it as the source of truth.

---

## Table of contents

1. What we are building
2. How a mobile app works (the mental model)
3. Tech stack and why each piece was chosen
4. Architecture: the four layers
5. Project folder structure
6. Data model (the database)
7. User journeys (and why they are shaped this way)
8. Screen map and navigation
9. Key technical flows, step by step
10. State management explained
11. Database lifecycle: creation, seeding, migrations
12. Cross-cutting concerns
13. Testing strategy
14. Decisions and trade-offs
15. Roadmap after v1
16. Glossary

---

## 1. What we are building

**FitLog** is an **offline-first Android workout tracker** for two kinds of people:

- **Gym-goers**: barbells, machines, cables, dumbbells.
- **Home exercisers**: bodyweight, dumbbells/kettlebells/bands, little or no equipment.

The user can follow a ready-made plan (or build their own), log every set during a workout, use a rest
timer, and later look back at history and progress.

### MVP (version 1) features

| # | Feature | Plain-English meaning |
|---|---------|-----------------------|
| 1 | Onboarding | First launch: choose gym / home / both, units (kg or lb), goal |
| 2 | Exercise library | ~80 built-in exercises, searchable, filterable by muscle / equipment / gym-or-home. User can add custom exercises |
| 3 | Plans (templates) | Pre-built plans for gym and home, plus user-made plans |
| 4 | Active workout | Start a workout, log sets (weight/reps/time), see what you did last time, rest timer |
| 5 | History | Calendar/list of past workouts, open one to see details, edit or delete |
| 6 | Progress | Personal records, strength charts per exercise, weekly volume, body-weight log |
| 7 | Settings and export | Units, theme, week start, export data to CSV |

### Explicitly out of scope for v1 (so we don't build blindly or endlessly)

User accounts / login, cloud sync, social features, AI coaching, exercise videos, wearables, payments,
iOS builds. **Why no iOS?** Building iOS apps requires a Mac. You are on Windows, so v1 targets Android only.
Flutter code is mostly reusable, so iOS can be added later by someone with a Mac.

---

## 2. How a mobile app works (the mental model)

Read this section slowly; everything else builds on it.

Imagine a **restaurant**:

| Restaurant | App | What it does |
|------------|-----|--------------|
| Dining room (what customers see) | **UI / Screens / Widgets** | What the user sees and taps |
| Waiters | **State management (providers)** | Carry information between the dining room and the kitchen; remember what is on screen right now |
| Kitchen managers | **Repositories** | Know *how* to get or save things ("get me all exercises for chest") without the waiters knowing the details |
| The pantry | **Database (SQLite)** | Where everything is stored permanently |

Key facts:

1. **The app runs entirely on the phone.** There is no server, no internet needed. The database is one
   file stored in the app's private storage on the phone. *Why:* it's faster to build, works in gym
   basements with no signal, costs nothing to host, and user data stays private.
2. **A screen is a tree of "widgets".** In Flutter, *everything visible* is a widget: text, buttons,
   padding, lists, whole screens. You build screens by nesting small widgets.
3. **State** is "the data the screen depends on right now" (e.g., the list of sets in the current
   workout). When state changes, Flutter **rebuilds** the affected widgets automatically. You never
   manually "update the label"; you change the state and the UI follows.
4. **Persistence** means saving data to the database so it survives the app being closed or the phone
   restarting. State lives in memory (lost when app closes); the database lives on disk (kept).
5. **Hot reload:** while developing, you save a file and the running app on your phone updates in about
   a second, without restarting. It's the main reason Flutter is pleasant to work with.

---

## 3. Tech stack and why each piece was chosen

| Piece | Choice | Why |
|-------|--------|-----|
| Language | **Dart** | The language Flutter uses. Easy to read, similar to Java/JavaScript |
| UI framework | **Flutter** | One codebase, fast UI, excellent tooling on Windows, hot reload |
| Database | **SQLite via `sqflite`** | SQLite is a small database engine built into Android. `sqflite` is the standard Flutter package for it. You write real SQL, so you learn transferable skills, and there is **no code generation step** (fewer things to break for a beginner) |
| State management | **`flutter_riverpod`** (no code generation) | Modern, testable, and hard to misuse. Plain `Notifier` / `AsyncNotifier` / `FutureProvider` are enough |
| Navigation | **`go_router`** | Officially maintained by the Flutter team; declarative routes; supports the bottom-tab shell we need |
| Charts | **`fl_chart`** | Popular, customizable line/bar charts |
| Screen stay-awake | **`wakelock_plus`** | Keeps the screen on during a workout |
| Formatting dates/numbers | **`intl`** | Locale-aware dates and numbers |
| Export/share | **`share_plus`** | Lets the user share a CSV file via the Android share sheet |
| DB tests on desktop | **`sqflite_common_ffi`** (dev only) | Lets automated tests run on your Windows PC without a phone |
| Icons | **`flutter_launcher_icons`** (dev only) | Generates the Android app icon from one image |

**Versions:** never hard-code versions from memory. The agent should add packages with
`flutter pub add <name>` so it gets the newest versions compatible with your Flutter SDK.

**Why not Drift / Floor / Isar / Hive?** Drift is excellent but requires code generation (`build_runner`),
which adds a confusing failure mode for first-timers. Hive/Isar are not SQL. You asked for SQLite, and
plain `sqflite` keeps the learning curve honest. (Trade-off recorded in section 14.)

---

## 4. Architecture: the four layers

We use a simple **layered architecture** inside each feature. Each layer only talks to the one directly
below it.

```
┌───────────────────────────────────────────────┐
│  1. PRESENTATION  (screens + widgets)         │  ← what the user sees
│     Only draws UI and forwards taps           │
├───────────────────────────────────────────────┤
│  2. STATE / APPLICATION  (Riverpod providers) │  ← "waiters"
│     Holds current screen data, runs actions   │
├───────────────────────────────────────────────┤
│  3. DOMAIN  (models + pure logic)             │  ← plain Dart classes
│     Exercise, WorkoutSession, SetEntry,       │
│     calculations (1RM, volume, PRs)           │
├───────────────────────────────────────────────┤
│  4. DATA  (repositories + SQLite)             │  ← "kitchen + pantry"
│     All SQL lives here and ONLY here          │
└───────────────────────────────────────────────┘
```

### The rules (the agent must follow these)

1. **Screens never write SQL and never touch the database directly.** They talk to providers.
2. **Providers call repositories.** Repositories are the *only* code that runs SQL.
3. **Domain models are plain Dart classes** with no Flutter or database imports (`fromMap`/`toMap`
   conversion lives in the data layer). *Why:* pure logic is trivially unit-testable.
4. **Calculations** (1RM, volume, PR detection, unit conversion) are **pure functions** in the domain
   layer: input in, output out, no side effects.
5. **Dependencies point downward only.** Data never imports from presentation.

**Why layers at all?** If you later change how data is stored (say, add cloud sync), only the data layer
changes. If you redesign a screen, the database is untouched. It also lets your coding agent work on one
layer at a time without breaking others.

---

## 5. Project folder structure

We use **feature-first** organization: everything about "history" lives together, rather than spreading
across a global `screens/` and `models/`. *Why:* as the app grows you find things by asking "what feature?"
not "what type of file?".

```
fitlog/
├── AGENTS.md                      # rules for the coding agent (from PROMPTS.md)
├── docs/
│   ├── ARCHITECTURE.md            # this file
│   └── PROMPTS.md                 # your phased prompts
├── assets/
│   ├── data/
│   │   ├── exercises.json         # built-in exercise library (seed data)
│   │   └── templates.json         # built-in plans (seed data)
│   └── icon/icon.png              # app icon source (you provide, Phase 9)
├── lib/
│   ├── main.dart                  # app entry point
│   ├── app/
│   │   ├── app.dart               # MaterialApp.router, theme wiring
│   │   ├── router.dart            # all routes (go_router)
│   │   └── theme.dart             # light/dark themes, colors, text styles
│   ├── core/
│   │   ├── database/
│   │   │   ├── app_database.dart  # opens DB, onCreate/onUpgrade, PRAGMAs
│   │   │   ├── migrations.dart    # numbered migration steps
│   │   │   └── seeder.dart        # loads JSON seeds into DB (idempotent)
│   │   ├── utils/                 # unit conversion, date helpers, formatters
│   │   └── widgets/               # shared widgets (empty state, error box...)
│   └── features/
│       ├── onboarding/
│       ├── exercises/
│       │   ├── data/              # exercise_repository.dart
│       │   ├── domain/            # exercise.dart
│       │   └── presentation/      # screens + widgets
│       ├── plans/                 # workout templates
│       ├── session/               # the ACTIVE workout (most complex feature)
│       ├── history/
│       ├── progress/
│       └── settings/
└── test/
    ├── domain/                    # pure-logic tests
    └── data/                      # repository tests using in-memory SQLite
```

---

## 6. Data model (the database)

SQLite stores data in **tables** (like spreadsheets): each **row** is one record, each **column** one
field. Tables link to each other with **foreign keys** (a column holding another table's `id`).

### 6.1 Entity relationship overview

```
exercises ◄───────────── template_exercises ─────────► workout_templates
    ▲                                                        │
    │                                                        │ (optional link: "started from plan X")
    │                                                        ▼
    └────────────────── session_exercises ─────────► workout_sessions
                               │
                               ▼
                          session_sets

body_weight_entries      user_settings       (standalone tables)
```

### 6.2 Tables

Conventions: `id` = auto-increment integer primary key. **Times are stored as integer epoch
milliseconds in UTC.** **Weights are always stored in kilograms** and converted for display.

**`exercises`**

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| slug | TEXT UNIQUE | Stable code name like `barbell_bench_press`. Lets seed files reference exercises without depending on auto ids |
| name | TEXT NOT NULL | Display name |
| primary_muscle | TEXT NOT NULL | chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core, forearms, full_body, cardio |
| secondary_muscles | TEXT | Comma-separated |
| equipment | TEXT NOT NULL | barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, none |
| environment | TEXT NOT NULL | `gym`, `home`, or `both` (where it is practical) |
| tracking_type | TEXT NOT NULL | `weight_reps`, `reps_only`, `duration` (see 6.3) |
| instructions | TEXT | Short how-to steps |
| is_custom | INTEGER | 0 built-in, 1 user-created |
| is_archived | INTEGER | Soft delete, so old history never breaks |

**`workout_templates`** — a saved plan (e.g., "Push Day")

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| slug | TEXT UNIQUE NULL | Only for built-in plans |
| name | TEXT NOT NULL | |
| description | TEXT | |
| environment | TEXT NOT NULL | gym / home / both |
| is_prebuilt | INTEGER | |
| created_at, updated_at | INTEGER | epoch ms |

**`template_exercises`** — the exercises inside a plan

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| template_id | INTEGER FK → workout_templates ON DELETE CASCADE | |
| exercise_id | INTEGER FK → exercises | |
| position | INTEGER | Order in the plan |
| target_sets | INTEGER | |
| target_reps_min / target_reps_max | INTEGER | e.g., 8–12. For `duration` exercises use `target_reps_min` as seconds |
| rest_seconds | INTEGER | Default rest for this exercise |
| notes | TEXT | |

**`workout_sessions`** — one actual workout the user performed (or is performing)

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| template_id | INTEGER NULL FK → workout_templates ON DELETE SET NULL | Null for empty workouts |
| name | TEXT NOT NULL | Copied from the plan at start (a **snapshot**) |
| environment | TEXT | gym / home |
| started_at | INTEGER NOT NULL | |
| ended_at | INTEGER NULL | **NULL means the workout is still in progress** |
| notes | TEXT | |

**`session_exercises`** — exercises performed in a session

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| session_id | INTEGER FK → workout_sessions ON DELETE CASCADE | |
| exercise_id | INTEGER FK → exercises | |
| position | INTEGER | |
| rest_seconds | INTEGER | Rest timer length for this exercise in this session |
| notes | TEXT | |

**`session_sets`** — every individual set

| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| session_exercise_id | INTEGER FK → session_exercises ON DELETE CASCADE | |
| set_number | INTEGER | 1, 2, 3… |
| weight_kg | REAL NULL | Null for bodyweight-only |
| reps | INTEGER NULL | |
| duration_seconds | INTEGER NULL | For timed exercises |
| is_warmup | INTEGER | Warm-up sets are excluded from PR and volume math |
| is_completed | INTEGER | Set is "done" only when the user ticks it |
| completed_at | INTEGER NULL | |

**`body_weight_entries`**: `id`, `weight_kg REAL`, `logged_at INTEGER`.

**`user_settings`** — simple key/value: `key TEXT PK`, `value TEXT`.
Keys: `unit_system` (`metric`/`imperial`), `environment_mode` (`gym`/`home`/`both`), `goal`,
`weekly_target`, `theme_mode` (`system`/`light`/`dark`), `week_start` (`monday`/`sunday`),
`onboarding_complete`, `seed_version`.

**Indexes** (make lookups fast): `session_sets(session_exercise_id)`, `session_exercises(session_id)`,
`session_exercises(exercise_id)`, `workout_sessions(started_at)`, `template_exercises(template_id)`,
`exercises(primary_muscle)`.

### 6.3 Why the data is shaped this way

1. **Templates vs. sessions are separate.** A template is the *plan* ("3×8–12 bench"). A session is
   *what actually happened* ("bench: 60×10, 60×9, 55×10"). If you edit the plan next month, last month's
   history must not change. So starting a workout **copies** the plan into `workout_sessions` /
   `session_exercises` (a snapshot). This is the single most important modeling decision in the app.
2. **`tracking_type`** avoids special-casing in the UI. Bench press logs weight + reps; push-ups log reps;
   plank logs seconds. The active-workout screen renders the right input columns per type.
3. **`ended_at IS NULL` = in progress.** Every completed set is written to the database immediately. If
   the phone dies, the app is killed, or the user gets a phone call, the workout is **not lost**;
   on next launch we offer "Resume workout".
4. **Soft delete (`is_archived`) for exercises.** Hard-deleting an exercise used in history would either
   break history or wipe it. Archived exercises are hidden from pickers but still display in history.
5. **Kilograms internally.** One unit in storage means no mixed-unit bugs; the UI converts (1 kg ≈ 2.20462 lb).
6. **Foreign keys must be switched on.** SQLite ignores foreign keys unless you run
   `PRAGMA foreign_keys = ON` every time a connection opens (done in `onConfigure`). A classic gotcha.

---

## 7. User journeys (and why they are shaped this way)

A **user journey** is the path someone walks through the app to achieve a goal. We design around the
moments that matter: *at the gym, sweaty, between sets, one hand free.* That is why the active workout
screen has large tap targets and minimal typing.

### Journey A — First launch (onboarding)

1. Welcome screen → 2. "Where do you train?" (Gym / Home / Both) → 3. Units (kg/lb) →
4. Goal (Build muscle / Get stronger / Lose fat / General fitness) and target days per week →
5. Land on Home with a suggested plan.

*Why:* the "gym vs. home" choice filters the exercise library and suggested plans so users never see
irrelevant equipment. Keep it to ~3 screens; every extra question loses users.

### Journey B — Do a workout (the core loop)

1. Home → tap **Start workout** on a plan (or **Start empty workout**).
2. App creates a session (`ended_at = NULL`) with snapshot exercises.
3. For each exercise, fill weight and reps (pre-filled from last time), tick the set. Ticking saves it
   and **auto-starts the rest timer**.
4. Optional: add an exercise, add/remove sets, mark warm-up.
5. Tap **Finish** → summary (duration, total volume, PRs hit) → saved to history.
   Or **Discard**.

*Why:* the pre-filled "previous" values are what makes tracking fast; progressive overload (doing a bit
more than last time) is the whole point of logging. Immediate saving makes it crash-proof.

### Journey C — Build or edit a plan

Plans tab → New plan → name → add exercises from the picker (filterable) → set sets/reps/rest →
reorder → save. Built-in plans can be **duplicated** and then edited (built-ins themselves stay pristine).

*Why:* letting users customize is essential, but protecting the built-ins means "Reset" is never needed.

### Journey D — Review history

History tab → list grouped by month (or calendar dots) → tap a session → see every exercise and set →
edit a set or delete the session.

*Why:* people mistype weights. Editing must be possible.

### Journey E — Track progress

Progress tab → pick an exercise → chart of estimated 1-rep-max over time → list of PRs → weekly
workout count and volume → log body weight.

*Why:* seeing a line go up is the motivation loop that keeps people using the app.

### Journey F — Resume an interrupted workout

App launch → repository finds a session with `ended_at IS NULL` → banner "Workout in progress — Resume /
Discard".

---

## 8. Screen map and navigation

```
Onboarding (only first launch)
   └─► App shell with bottom navigation (4 tabs)
        ├─ Home
        │    ├─ Start workout (from plan) ─► ACTIVE WORKOUT (full screen, hides tabs) ─► Summary
        │    └─ Settings (gear icon)
        ├─ Plans
        │    ├─ Segmented: My Plans | Exercise Library
        │    ├─ Plan detail ─► Plan editor ─► Exercise picker
        │    └─ Exercise detail / Create custom exercise
        ├─ History
        │    └─ Session detail (edit sets / delete)
        └─ Progress
             ├─ Exercise progress detail (chart + PRs)
             └─ Body weight log
```

*Why bottom tabs:* the four sections are equal-priority and used constantly; bottom tabs are reachable
with the thumb. *Why is the active workout full-screen (outside the tab shell)?* It is a focused mode;
accidentally switching tabs mid-set would be frustrating.

---

## 9. Key technical flows, step by step

### 9.1 Starting a workout

1. UI: user taps Start on plan #4.
2. Provider `activeSessionProvider.startFromTemplate(4)` is called.
3. Repository opens a **transaction** (all-or-nothing): insert into `workout_sessions`; for each
   `template_exercises` row insert a `session_exercises` row; pre-create N empty `session_sets` rows
   (target sets) with `is_completed = 0`.
4. Provider loads the full session and exposes it as state; router navigates to `/session/active`.

*Why a transaction:* if the app dies halfway you don't get a session with missing exercises.

### 9.2 Logging a set

1. User edits weight/reps in a row (kept in the widget's local text controllers).
2. User taps ✓. Provider `completeSet(setId, weight, reps)` runs.
3. Repository `UPDATE session_sets SET weight_kg=?, reps=?, is_completed=1, completed_at=? WHERE id=?`.
4. Provider refreshes state → row turns green; rest timer starts.

### 9.3 "Previous" values

Query: for exercise E, find the most recent **completed** session (excluding the current one) containing
E, and return its non-warm-up sets. Show them in a "Previous" column and use them to pre-fill.

### 9.4 Rest timer

Store `restEndsAt = now + restSeconds` (a timestamp), and compute "seconds left" from the clock on each
tick, **not** by counting ticks. *Why:* if the app is backgrounded or the screen turns off, counting
ticks drifts; comparing against the clock is always right. When it hits zero, haptic feedback/vibration.
(A background notification is a v1.1 item because Android's notification permissions add complexity.)

### 9.5 Finishing

Set `ended_at = now`, delete sets that were never completed (empty rows), drop exercises with zero
completed sets (after confirming with the user), compute summary (duration, volume, PRs), navigate
to the summary screen.

### 9.6 Calculations (pure functions in `domain/`)

- **Volume** = Σ (weight_kg × reps) over completed, non-warm-up sets.
- **Estimated 1RM (Epley)** = weight × (1 + reps / 30). For reps = 1, e1RM = weight.
- **Personal record (PR)** types: heaviest weight; highest e1RM; most reps (for `reps_only`); longest
  duration (for `duration`). A set is a PR if it beats all earlier completed sets for that exercise.
- **Unit conversion**: `kgToLb(kg) = kg × 2.20462`; display rounded to 1 decimal (or nearest 0.5 for
  input steppers).

### 9.7 Resume detection

At startup after DB opens: `SELECT * FROM workout_sessions WHERE ended_at IS NULL ORDER BY started_at
DESC LIMIT 1`. If found, show the resume banner on Home.

---

## 10. State management explained

**Problem:** many screens need the same data (the active workout is read by the workout screen, the
rest-timer bar, and the Home "resume" banner). Passing it manually is painful.

**Solution (Riverpod):** a **provider** is a globally accessible, observable holder of a value. Widgets
"watch" it and rebuild when it changes.

Three kinds we will use:

| Kind | Used for | Example |
|------|----------|---------|
| `Provider` | Things that never change | `databaseProvider`, repositories |
| `FutureProvider` / `AsyncNotifier` | Data loaded asynchronously | `exerciseListProvider(filter)` |
| `Notifier` | State you change with actions | `ActiveSessionNotifier` with methods `completeSet`, `addSet`, `finish` |

Pattern:

```dart
// (illustrative only — the agent writes the real code)
final exerciseRepositoryProvider = Provider((ref) => ExerciseRepository(ref.watch(databaseProvider)));

final exercisesProvider = FutureProvider.family<List<Exercise>, ExerciseFilter>((ref, filter) {
  return ref.watch(exerciseRepositoryProvider).search(filter);
});
```

A screen does `ref.watch(exercisesProvider(filter))` and gets loading / error / data states for free.
**We do not use code-generated Riverpod (`riverpod_generator`)** to avoid `build_runner`.

**Local vs. global state:** text being typed in a field stays local to that widget; anything that must
survive navigation or be shared goes into a provider.

---

## 11. Database lifecycle: creation, seeding, migrations

- **Opening:** `AppDatabase.open()` finds the file path (`getDatabasesPath()` + `fitlog.db`), calls
  `openDatabase(version: N, onConfigure, onCreate, onUpgrade)`. `onConfigure` enables foreign keys.
- **onCreate:** runs once on a fresh install; creates every table and index in a single transaction.
- **Seeding:** after opening, the `Seeder` reads `assets/data/exercises.json` and `templates.json` and
  inserts rows **idempotently** (matching on `slug`, using `INSERT ... ON CONFLICT DO NOTHING` or a
  check-then-insert). It records `seed_version` in `user_settings`; if a new app version ships with a
  higher `seed_version`, only the new items are added. *Why idempotent:* running twice must never
  create duplicates or overwrite user changes.
- **Migrations (schema changes after release):** when you later add a column, bump the DB `version`,
  and add a numbered step in `migrations.dart` (e.g., `if (oldVersion < 2) { ALTER TABLE ... }`).
  **Never edit an old migration; always add a new one.** Users update the app and their existing data
  must survive.
- **All multi-step writes use transactions.**

---

## 12. Cross-cutting concerns

- **Error handling:** repositories throw typed exceptions; providers expose `AsyncValue.error`;
  screens show a friendly message with a Retry button — never a red crash screen.
- **Empty states:** every list has a friendly empty state with a call to action ("No workouts yet — start one").
- **Loading states:** skeletons or spinners; never a blank screen.
- **Theming:** Material 3, seed-color based, light + dark + system. Colors defined once in `theme.dart`.
- **Accessibility:** tap targets at least 48×48 dp; respects system font scaling; sufficient color contrast;
  don't rely on color alone (ticks also change icon).
- **Performance:** use `ListView.builder` for long lists; database indexes; avoid rebuilding whole
  screens (watch narrow providers).
- **Input validation:** weight 0–1000 kg, reps 0–1000, duration ≤ 24 h; decimal comma tolerated.
- **Privacy/security:** data never leaves the device (no network permission requested in v1). Export is
  user-initiated. Because there is no server, there are no accounts or passwords to protect.
- **Health disclaimer:** an in-app note that this app is not medical advice, and exercise instructions
  are general guidance. Built-in exercise text is AI-assisted and **must be reviewed by you** before release.
- **Permissions:** v1 needs none beyond defaults (wakelock and vibration are normal permissions).
- **Time:** stored as UTC epoch ms; displayed in local time; "week" boundaries follow the `week_start` setting.

---

## 13. Testing strategy

| Level | What | How | Where |
|-------|------|-----|-------|
| Unit | Calculations (1RM, volume, PR, unit conversion) | `flutter test`, no database | `test/domain/` |
| Repository | SQL correctness, seeding idempotency, transactions | `sqflite_common_ffi` with an in-memory DB, runs on your PC | `test/data/` |
| Widget | Key screens render and respond (empty state, set tick) | `flutter test` with `testWidgets` | `test/widgets/` |
| Manual | Real behavior on your phone | Checklist at the end of every phase in PROMPTS.md | — |

`flutter analyze` (static checks) and `flutter test` must be clean **before** you move to the next phase.

---

## 14. Decisions and trade-offs

| Decision | Alternatives | Why we chose this | Cost |
|----------|--------------|-------------------|------|
| Offline-only, no backend | Firebase / custom API | Fastest to ship, private, works anywhere | No cross-device sync or cloud backup (mitigated by CSV export) |
| `sqflite` (raw SQL) | Drift, Isar, Hive | No code generation; teaches SQL | More boilerplate; manual mapping |
| Riverpod without codegen | Provider, Bloc, GetX | Testable, scalable, no build_runner | Slightly more verbose |
| Feature-first folders | Layer-first | Scales by feature | Some shared code needs `core/` |
| Snapshot on workout start | Reference live template | History never changes retroactively | Slight data duplication (worth it) |
| Weights stored in kg | Store as entered | One canonical unit | Conversion at display edges |
| Rest timer via timestamps | Tick counter | Correct when backgrounded | Slightly more code |
| In-app timer only in v1 | Background notifications | Avoids permission/alarm complexity | User must keep app open |
| Android only | + iOS | Windows can't build iOS | No iPhone users yet |

---

## 15. Roadmap after v1

Rest-timer notifications, supersets, plate calculator, exercise images/GIFs, cloud backup (e.g., Google
Drive export/import), home-screen widget, Wear OS, Health Connect integration, program progression
(auto-increase weights), iOS release.

---

## 16. Glossary

- **Widget** — a building block of Flutter UI (text, button, screen…).
- **State** — data that determines what the UI shows right now.
- **Provider (Riverpod)** — an observable container for state or services.
- **Repository** — a class that hides *how* data is stored/fetched.
- **Model** — a plain class representing a thing (Exercise, SetEntry).
- **SQL** — the language for talking to databases (`SELECT`, `INSERT`, `UPDATE`, `DELETE`).
- **Primary key / Foreign key** — a row's unique id / a column pointing to another table's row.
- **Transaction** — a group of database operations that all succeed or all fail.
- **Migration** — a scripted change to the database structure for existing users.
- **Seed data** — built-in starter data loaded on first run.
- **Idempotent** — safe to run repeatedly with the same result.
- **Hot reload** — apply code changes to the running app instantly.
- **APK** — the installable Android app file.
- **Debug vs. release build** — debug is for development (slower, has tools); release is optimized for real use.
- **Epley formula** — estimate of the most weight you could lift once, from a set of several reps.
- **Volume** — total weight lifted (weight × reps summed).
- **PR** — personal record.
- **Progressive overload** — gradually doing more (weight/reps) over time to keep improving.
