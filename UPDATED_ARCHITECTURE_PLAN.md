# Liturgical Reader – Architecture Plan (2025-08-02)

> Living document — update whenever architecture changes.

## Table of Contents
1. Project Overview
2. Codebase Snapshot ‑ Current State
3. Guiding Principles
4. Logical Architecture
5. Data Architecture
6. Runtime Architecture
7. DevOps & Deployment
8. Gap Analysis & Needed Work
9. Road-map
10. Quality Assurance

---
## 1. Project Overview
Liturgical Reader is a Flutter application delivering daily Catholic liturgical readings with **offline-first** reliability. Core objectives:
* Instant, offline access to today’s readings.
* Interactive liturgical calendar (±90 days).
* Bookmarks and (future) audio playback.
* Editorial feedback loop via admin review.

Backend promises:
* Canonical data in Supabase (Postgres) under row-level security.
* Self-healing sync process keeping local SQLite cache in parity.
* Feature flags and staged rollout for safe deployments.

---
## 2. Codebase Snapshot – Current State
Directory overview:
```text
lib/
  core/            # exports
  models/          # data classes (LiturgicalDay, Reading, …)
  services/        # business & infrastructure services
  presentation/    # screens + widgets
  routes/          # AutoRoute definitions
  theme/           # ThemeData & extensions
  widgets/         # shared widgets
assets/
supabase/          # SQL schema & seed files
android/, ios/     # platform shells
```
Implemented highlights:
* Offline cache (`OfflineStorageService`) with rich schema & indices.
* Supabase integration (`SupabaseService`) and fallback `CatholicApiService`.
* Orchestration (`OfflineFirstLiturgicalService`) with scheduler & validation helpers.
* Connectivity monitoring & background pre-fetch.
* Initial UI screens: Splash, Today’s Readings, Calendar, Reading Detail.
* Material 3 theming via `app_theme.dart`.

Missing / partial:
* Riverpod state wiring across UI.
* Audio playback, push notifications, search, preferences.
* Automated tests; CI/CD and monitoring hooks.

---
## 3. Guiding Principles
1. **Clean Architecture** — isolate layers, depend on abstractions.
2. **Offline-First** — local cache is primary read path, network augments.
3. **Composable Services** — single-responsibility, easy to test.
4. **Functional-Reactive UI** — Riverpod providers feed immutable view-state.
5. **Security by Default** — encrypted storage, RLS, secure env.

---
## 4. Logical Architecture
```
┌────────── Presentation ──────────┐
│ Widgets → Screens → ViewModels   │  (Riverpod Notifiers)
└───────────────────────────────────┘
        ↓ uses                   ↑ emits
┌────────── Service / Domain ────┐
│ OfflineFirstLiturgicalService  │
│ ├ CalendarService              │
│ ├ SchedulerService             │
│ ├ ValidationService            │
│ ├ SyncManager                  │
│ └ ConnectivityService          │
└─────────────────────────────────┘
        ↓ repository pattern
┌──────── Infrastructure ────────┐
│ SupabaseService | ApiService   │
│ OfflineStorageService (SQLite) │
└─────────────────────────────────┘
```
Control flow: UI asks Domain → returns cached data immediately → Domain syncs in background → UI receives updates via Riverpod.

---
## 5. Data Architecture
* **Supabase Postgres** is the single source of truth, protected by RLS.
* **SQLite Cache** mirrors a subset with a `cache_timestamp` column.
* **Sync Queue** table (future) to track offline edits (bookmarks, notes).
* Scheduler trims cache to ±90 days window to bound DB size.

ER snapshot:
```
LiturgicalDay 1───* LiturgicalReading
LiturgicalDay 1───* ValidationReport
User          1───* UserBookmark (future)
```

---
## 6. Runtime Architecture
| Concern           | Solution                                  |
|-------------------|-------------------------------------------|
| State management  | Riverpod + get_it                         |
| Navigation        | AutoRoute 6                               |
| Theming           | Material 3 via `app_theme.dart`            |
| Background tasks  | workmanager / BGProcessingTask            |
| Networking        | http + Supabase Dart SDK                  |
| Storage           | sqflite + path_provider                   |

---
## 7. DevOps & Deployment
1. **Git** — remote on GitHub; all merges to `main` trigger CI.
2. **CI** — GitHub Actions: lint ➜ tests ➜ build artefacts.
3. **CD** — Fastlane (iOS TestFlight) & Gradle Play Publisher (.aab) for Android.
4. **Feature Flags** — Supabase `config` table; fallback `env.json`.
5. **Monitoring** — Firebase Crashlytics & Performance, Sentry for non-fatal errors.
6. **Backups** — Supabase daily dump; artefacts on GitHub Releases.

---
## 8. Gap Analysis & Needed Work
| Area                   | Status | Action Items |
|------------------------|--------|--------------|
| Git remote / backups   | ⚠️     | Init repo, push on each merge |
| Automated tests        | 🔴     | Unit & widget test suites |
| Riverpod integration   | 🟡     | Replace ad-hoc state |
| Audio playback         | 🔴     | Implement with just_audio |
| Push notifications     | 🔴     | Firebase Messaging |
| CI/CD pipeline         | 🟡     | Configure workflows + Fastlane |
| Monitoring             | 🔴     | Integrate Crashlytics/Sentry |
| Search & preferences   | 🔴     | Design & implement |
| Admin review UI        | 🟡     | Connect to validation services |

Legend: 🔴 = not started, 🟡 = partial, ⚠️ = outside codebase.

---
## 9. Road-map
1. **Foundations (0-4 wks)** — repo + CI + tests + Riverpod wiring.
2. **User features (1-3 mo)** — audio, search, preferences, notifications.
3. **Quality & Admin (3-6 mo)** — validation dashboard, analytics.
4. **Platform expansion (6-12 mo)** — web/desktop, integrations API.

---
## 10. Quality Assurance
* **Testing pyramid** — 70 % unit, 20 % widget, 10 % E2E/integration.
* **Static analysis** — `flutter analyze`, `dart_code_metrics` in CI.
* **Performance budgets** — cold-start ≤ 1.5 s, frame build ≤ 16 ms.

---
_Last updated: 2025-08-02_
