# Change-log

All notable changes to **Liturgical Reader** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] – 2025-08-02
### Added
* Offline-first cache (90-day window) with SQLite.
* Supabase integration for canonical data.
* Initial UI: Splash, Today’s Readings, Calendar, Reading Detail.
* Feature-flag service (compile-time + Supabase overrides).
* Crash reporting (Sentry) and performance monitoring (Firebase Performance).
* GitHub Actions: release build workflow, nightly DB snapshot.

### Fixed
* N/A – first release.

### Deprecated / Removed / Security
* None.
