# Liturgical Reader – Knowledge Base

Welcome to the user-support hub for the **Liturgical Reader** mobile app. Here you’ll find everything you need to install the app, understand key features, troubleshoot issues, and track what’s new.

---
## Table of Contents
1. [Install Guide](#install-guide)
2. [Sign-in & Accounts](#sign-in--accounts)
3. [Offline-First Explained](#offline-first-explained)
4. [Known Issues & Work-arounds](#known-issues--work-arounds)
5. [Change-log](#change-log)
6. [Contact Support](#contact-support)

---
## Install Guide
### Android
1. Download the latest **.aab** or **.apk** from the GitHub **Releases** page.
2. Enable *Install from unknown sources* in Settings → Security (if sideloading).
3. Tap the file and follow the prompts.

### iOS
1. Join the TestFlight beta via the public link provided on the project page.
2. Install the latest build in the TestFlight app.

### Minimum OS versions
* Android 8.0 (API 26)
* iOS 13.0

---
## Sign-in & Accounts
Liturgical Reader currently works **without an account**. Future versions may add optional sign-in for cross-device bookmarks.

---
## Offline-First Explained
• The app caches **30 days past** and **60 days future** readings in a local SQLite database.  
• When online, new data syncs silently in the background.  
• You can safely read while in Airplane Mode or with poor reception.

---
## Known Issues & Work-arounds
| Issue | Status | Work-around |
|-------|--------|-------------|
| Blank day shows “No readings available” | Investigating | Pull-to-refresh while online or wait for background sync |
| Audio playback button missing | Feature under development | — |
| Push notifications not received | Not implemented yet | — |

---
## Change-log
See `CHANGELOG.md` in the repository for developer-focused details. Major user-visible highlights are listed below.

### 1.0.0 (2025-08-02)
* Initial public beta  
* Daily readings with offline cache  
* Interactive liturgical calendar  
* Basic bookmark support  
* Admin review (hidden, feature-flagged)

---
## Contact Support
• Email: [support@liturgicalreader.app](mailto:support@liturgicalreader.app?subject=Liturgical%20Reader%20Support)  
• GitHub Issues: <https://github.com/your-user/liturgicalreader/issues>

We aim to reply within 48 hours.
