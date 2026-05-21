# Changelog

All notable changes to this project will be documented in this file.

---

## [1.0.0] - 2026-05-21 (Initial Public Release)

### Summary
Sub Manager helps you track and manage recurring subscriptions and bills across platforms. This initial public release delivers core subscription management features, reminders, and a polished cross-platform Flutter UI.

### Highlights
- **Add & Manage Subscriptions:** Create, edit and categorize subscriptions with name, amount, billing cycle, and next-due date.  
- **Billing Calendar & Reminders:** View upcoming charges and receive local reminders/notifications for due subscriptions.  
- **Export / Backup:** Export subscription data for backup and manual transfer.  
- **Cross-platform:** Builds for Android, iOS, Web, Windows, macOS and Linux (where platform toolchains are available).  
- **Polished UI:** Screens and assets included for a clear, modern experience.

### Improvements
- Optimized data model for recurring billing calculation.  
- Faster list rendering and improved empty-state flows.  
- Better error handling for network and local storage operations.

### Bug Fixes
- Fixed crash when creating subscriptions without an amount set.  
- Fixed timezone issues that could shift next-due dates for some locales.  
- Resolved UI clipping on small screens and long subscription names.

### Upgrade / Migration Notes
No breaking data migrations in this release. Existing local data should be preserved on upgrade. If you encounter any data issues, export first and open an issue.

### How to Install / Run
Get dependencies:
```bash
flutter pub get
```
