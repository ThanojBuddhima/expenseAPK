# Smart Offline Expense Manager

Cross-platform Flutter app for **offline-first** personal expense tracking (Android, iOS, and web for development).

Aligned with the project proposal, **excluding cloud backup** (no Google Drive, restore, or backup settings).

## Features

| Area | Included |
|------|----------|
| **Expense management** | Add, edit, delete, search, filter by date and category |
| **Categories** | Create, edit, delete categories with colors |
| **Accounts** | Cash default + custom accounts |
| **Budgets** | Monthly overall (and per-category) budgets with progress on dashboard |
| **Analytics** | Income vs expenses, pie chart, category breakdown, trend line chart |
| **Security** | PIN lock, optional biometric unlock |
| **Appearance** | Light / dark mode |
| **Offline** | Local SQLite (in-memory fallback on web) |

## Screens

- Splash
- Dashboard (expense history + search)
- Add / edit expense
- Analytics
- Categories
- Settings (security, theme, budgets, accounts)
- Authentication (PIN / biometrics)

## Quick start

```bash
flutter pub get
flutter run
```

Web: `flutter run -d chrome`

## Tests

```bash
flutter test
```

## Tech stack

- Flutter / Dart
- sqflite (local database)
- fl_chart (analytics charts)
- local_auth (biometrics)
- shared_preferences (settings)

## Not in scope (per request)

- Encrypted cloud backup
- Google Drive integration
- Backup restore / backup history
