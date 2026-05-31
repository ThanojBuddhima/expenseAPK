# Smart Offline Expense Manager

<p align="center">
  <a href="https://github.com/ThanojBuddhima/expenseAPK/releases/latest/download/app-release.apk">
    <img src="https://img.shields.io/badge/Download-Latest%20APK-FF9800?style=for-the-badge&logo=android&logoColor=white" alt="Download Latest APK"/>
  </a>
  &nbsp;
  <a href="https://github.com/ThanojBuddhima/expenseAPK/releases/latest">
    <img src="https://img.shields.io/badge/View-All%20Releases-1E293B?style=for-the-badge&logo=github&logoColor=white" alt="View All Releases"/>
  </a>
</p>

<p align="center">
  <a href="https://github.com/ThanojBuddhima/expenseAPK/releases/latest/download/app-release.apk"><strong>⬇ Download app-release.apk (latest)</strong></a>
</p>

[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.0-0175C2?logo=dart&logoColor=white)](https://dart.dev)

Cross-platform **offline-first** personal finance app built with Flutter. Track income and expenses, manage budgets, and view analytics — all stored locally on your device with optional PIN and biometric protection.

> **Privacy by design:** No cloud sync, no accounts, no telemetry. Your data stays on your device.

---

## Table of contents

- [Download](#download)
- [Features](#features)
- [Screens & navigation](#screens--navigation)
- [First-time setup (onboarding)](#first-time-setup-onboarding)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Run on different platforms](#run-on-different-platforms)
- [Build release APK](#build-release-apk)
- [Automated releases (CI)](#automated-releases-ci)
- [Testing](#testing)
- [Configuration & permissions](#configuration--permissions)
- [Data storage](#data-storage)
- [Supported currencies](#supported-currencies)
- [Default categories](#default-categories)
- [Troubleshooting](#troubleshooting)
- [Out of scope](#out-of-scope)
- [License](#license)

---

## Download

<p align="center">
  <a href="https://github.com/ThanojBuddhima/expenseAPK/releases/latest/download/app-release.apk">
    <img src="https://img.shields.io/badge/Download-Latest%20Release-FF9800?style=for-the-badge&logo=android&logoColor=white" alt="Download Latest Release"/>
  </a>
</p>

| | |
|---|---|
| **Direct APK link** | [app-release.apk](https://github.com/ThanojBuddhima/expenseAPK/releases/latest/download/app-release.apk) |
| **Releases page** | [github.com/ThanojBuddhima/expenseAPK/releases/latest](https://github.com/ThanojBuddhima/expenseAPK/releases/latest) |

Install on Android: download the APK, then allow installation from your browser or file manager if prompted.

```text
https://github.com/ThanojBuddhima/expenseAPK/releases/latest/download/app-release.apk
```

---

## Features

### Transactions

| Capability | Details |
|------------|---------|
| **Add transactions** | Record **income** or **expense** with amount, title, category, account, date, and optional notes |
| **Edit & delete** | Tap a transaction to edit; swipe left to delete, swipe right to edit |
| **Search** | Full-text search across title, category, and notes on the dashboard |
| **Period filtering** | Navigate by **day**, **week**, **month**, or **year** |
| **Category filtering** | Horizontal chip filter on the dashboard |
| **Smart defaults** | Account and category are not pre-selected unless only one option exists; validation prompts if missing |
| **Income categories** | Salary, Bonus, Allowance, Other |
| **Expense categories** | User-managed categories from the database |

### Dashboard

- Period navigator with income / expense / net summary strip
- Monthly **budget progress** bar when an overall budget is set
- Transaction list with color-coded income vs expense amounts
- Pull-to-refresh
- Empty states with theme-aware icons

### Analytics

- Toggle between **Income** and **Expenses** views
- **Pie chart** — spending or income breakdown by category
- **Spending trend** line chart for the selected period
- Period navigation (daily / weekly / monthly / yearly)

### Accounts

- Built-in **Cash** account
- Create custom accounts with name and color
- Edit and delete custom accounts
- Assign an account per transaction

### Categories

- Seeded default expense categories on first launch
- Create, edit, and delete categories
- Pastel color picker per category
- Used in transactions, budgets, and analytics

### Budgets

- Set **monthly overall** or **per-category** budgets
- Category picker populated from your saved categories (not free text)
- Budget progress shown on the dashboard
- Dedicated budget management screen with add / edit / delete

### Calculator

- Built-in calculator tab for quick arithmetic
- Standard operations: add, subtract, multiply, divide
- Percentage and sign toggle
- Theme-aware styling

### Settings

| Section | Options |
|---------|---------|
| **Appearance** | Light, Dark, or **Device** theme (follows system) |
| **Security** | 4-digit PIN lock, optional biometric unlock, change PIN |
| **General** | Default currency (amount type) |
| **Accounts** | Manage accounts |
| **Categories** | Manage categories |
| **Budgets** | Manage budgets |

### Security

- **PIN lock** — 4-digit PIN with dot indicators and numeric keypad
- **Biometric unlock** — Fingerprint / Face ID (Android & iOS; requires PIN to be enabled first)
- Auto biometric prompt on lock screen when enabled
- PIN hashed locally before storage

### Onboarding

First launch walks through:

1. **Currency** — choose default amount type
2. **Categories** — select which expense categories to keep
3. **Accounts** — pick suggested accounts and/or add custom ones
4. **PIN** — optional 4-digit app lock setup

Existing users with data skip onboarding automatically.

### UI / UX

- Material 3 design with orange brand accent
- Light and dark themes with pastel palette
- Floating **island-style** bottom navigation bar
- Frosted / blurred navigation bar with centered add button
- Full-width primary action buttons (12 px radius)
- Responsive layouts with bottom safe-area padding

### Offline-first

- **SQLite** database on Android, iOS, macOS, Linux, and Windows
- **In-memory fallback** on web (data resets on page refresh)
- **SharedPreferences** for settings (in-memory fallback if unavailable)
- No network required for core functionality

---

## Screens & navigation

```
Splash → Onboarding (first launch) → Auth lock (if PIN enabled) → Dashboard
```

| Tab | Screen |
|-----|--------|
| Dashboard | Home — transactions, search, filters, summary, budget progress |
| Analytics | Charts and category breakdown |
| **+** (center) | Add transaction sheet |
| Calculator | Quick calculator |
| Settings | Theme, security, currency, manage screens |

**Manage screens** (from Settings):

- Accounts
- Categories
- Budgets

---

## First-time setup (onboarding)

| Step | What you configure |
|------|-------------------|
| 1 | Default currency (USD, GBP, EUR, INR, LKR, AUD, CAD, JPY, SGD, AED) |
| 2 | Expense categories to activate |
| 3 | Optional accounts (Savings, Wallet, Bank, or custom) |
| 4 | Optional 4-digit PIN |

You can change all of these later in **Settings**.

---

## Tech stack

| Layer | Technology |
|-------|------------|
| Framework | [Flutter](https://flutter.dev) (stable channel) |
| Language | Dart ≥ 3.0 |
| Local database | [sqflite](https://pub.dev/packages/sqflite) |
| Charts | [fl_chart](https://pub.dev/packages/fl_chart) |
| Biometrics | [local_auth](https://pub.dev/packages/local_auth) |
| Preferences | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| State | Flutter `StatefulWidget` + `IndexedStack` |
| Paths | [path_provider](https://pub.dev/packages/path_provider), [path](https://pub.dev/packages/path) |

---

## Project structure

```
lib/
├── main.dart                 # App entry, dashboard, transactions, accounts UI
├── app_theme.dart            # Light/dark themes, colors, button styles
├── models/
│   ├── account.dart
│   ├── budget.dart
│   ├── category.dart
│   ├── currency_option.dart
│   ├── expense.dart
│   └── time_period.dart
├── screens/
│   ├── auth_lock_screen.dart # PIN / biometric unlock
│   ├── budgets_tab.dart      # Budget management
│   ├── calculator_tab.dart   # Calculator
│   ├── categories_tab.dart   # Category management
│   ├── onboarding_screen.dart
│   ├── settings_tab.dart
│   └── splash_screen.dart
├── services/
│   ├── app_preferences.dart  # PIN, theme, currency, onboarding flags
│   ├── auth_service.dart     # PIN hash, biometric auth
│   ├── backup_service.dart   # JSON export/import (local, not wired to UI)
│   ├── currency_service.dart # Formatting & default currency
│   ├── db_service.dart       # SQLite / in-memory persistence
│   └── ocr_service.dart      # Receipt OCR placeholder
└── widgets/
    ├── bottom_add_button.dart
    ├── frosted_bar.dart
    ├── outlined_choice_button.dart
    ├── period_navigator_bar.dart
    ├── pin_keypad.dart
    └── spending_trend_chart.dart

test/
├── db_service_test.dart      # Database unit tests
└── widget_test.dart          # Dashboard smoke test

android/   ios/   web/   macos/   linux/   windows/   # Platform runners
```

---

## Prerequisites

| Tool | Version / notes |
|------|-----------------|
| **Flutter SDK** | Stable channel ([install guide](https://docs.flutter.dev/get-started/install)) |
| **Dart** | ≥ 3.0 (bundled with Flutter) |
| **Java (Android builds)** | **JDK 17** recommended (Temurin). Newer JDK versions may fail Gradle builds. |
| **Android Studio / SDK** | For Android emulator and APK builds |
| **Xcode** | For iOS/macOS (macOS only) |
| **Chrome** | For web development |

Verify your setup:

```bash
flutter doctor -v
```

---

## Getting started

```bash
# Clone the repository
git clone https://github.com/ThanojBuddhima/expenseAPK.git
cd expenseAPK

# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

---

## Run on different platforms

```bash
# Android (device or emulator)
flutter run

# iOS simulator (macOS only)
flutter run -d ios

# Web (development — in-memory storage, no biometrics)
flutter run -d chrome

# macOS desktop
flutter run -d macos

# Windows desktop
flutter run -d windows

# Linux desktop
flutter run -d linux
```

### Platform notes

| Platform | Database | Biometrics | Notes |
|----------|----------|------------|-------|
| Android | SQLite | ✅ Fingerprint / face | Full feature set |
| iOS | SQLite | ✅ Touch ID / Face ID | Requires `NSFaceIDUsageDescription` (included) |
| Web | In-memory | ❌ | Data lost on refresh; useful for UI dev |
| macOS / Windows / Linux | SQLite | Varies | Desktop builds supported |

---

## Build release APK

```bash
flutter pub get
flutter build apk --release
```

Output:

```
build/app/outputs/flutter-apk/app-release.apk
```

### JDK 17 (if Android build fails)

If Gradle fails with a Java version error, point Gradle to JDK 17 in `android/gradle.properties`:

```properties
org.gradle.java.home=/path/to/jdk-17
```

Example (macOS with Temurin):

```properties
org.gradle.java.home=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home
```

---

## Automated releases (CI)

GitHub Actions builds and publishes the APK when:

- A tag matching `v*` is pushed (e.g. `v1.0.0`), or
- The workflow is triggered manually (`workflow_dispatch`)

Workflow file: [`.github/workflows/release.yml`](.github/workflows/release.yml)

Steps: checkout → Java 17 → Flutter stable → `flutter build apk --release` → upload to GitHub Release.

---

## Testing

```bash
# Run all tests
flutter test

# Static analysis
flutter analyze
```

**Test coverage includes:**

- Expense CRUD (insert, read, delete)
- Income vs expense transaction types
- Account CRUD
- Category seeding and management
- Expense search
- Monthly budget storage
- Dashboard widget smoke test

---

## Configuration & permissions

### Android (`android/app/src/main/AndroidManifest.xml`)

- `USE_BIOMETRIC` — required for fingerprint / face unlock
- `MainActivity` extends `FlutterFragmentActivity` (required by `local_auth`)

### iOS (`ios/Runner/Info.plist`)

- `NSFaceIDUsageDescription` — required for Face ID / Touch ID prompt text

### Theme preference values (`shared_preferences`)

| Stored value | `ThemeMode` |
|--------------|-------------|
| `light` | Always light |
| `dark` | Always dark |
| `system` | Follow device setting |

---

## Data storage

### SQLite schema (mobile / desktop)

| Table | Purpose |
|-------|---------|
| `expenses` | Transactions (amount, currency, date, category, account, type, title, notes) |
| `accounts` | Custom accounts (name, balance, color) |
| `categories` | Expense categories (name, color) |
| `budgets` | Monthly budgets (overall or per-category) |

Database file: `expenses.db` in the app documents directory.

### Preferences (SharedPreferences)

- PIN enabled / hash
- Biometric enabled
- Theme mode
- Onboarding complete
- Default currency code

---

## Supported currencies

| Code | Region | Symbol |
|------|--------|--------|
| USD | United States | $ |
| GBP | United Kingdom | £ |
| EUR | European Union | € |
| INR | India | Rs. |
| LKR | Sri Lanka | Rs. |
| AUD | Australia | A$ |
| CAD | Canada | C$ |
| JPY | Japan | ¥ |
| SGD | Singapore | S$ |
| AED | United Arab Emirates | AED |

Change the default in **Settings → Amount type**.

---

## Default categories

Seeded on first database creation:

Food · Transport · Shopping · Bills · Entertainment · Health · General

Each category has an assigned pastel color used in charts and chips.

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| **Biometrics not working** | Enable PIN first, then biometric unlock in Settings. Test on a real device — biometrics are not available on web. Ensure fingerprint/Face ID is enrolled on the device. |
| **Biometric toggle won't stay on** | You must complete a successful biometric prompt when enabling the toggle. |
| **Android build Java error** | Use JDK 17; set `org.gradle.java.home` in `android/gradle.properties`. |
| **Web data disappears** | Expected — web uses in-memory storage. Use Android/iOS for persistent data. |
| **APK install blocked** | Allow "Install from unknown sources" or sideload via `adb install app-release.apk`. |
| **Hot reload after native changes** | PIN/biometric and Android manifest changes require a **full restart** (`R` in terminal or stop & re-run). |

---

## Out of scope

The following are **not included** in this build (per project scope):

- Encrypted cloud backup
- Google Drive integration
- Backup restore / backup history UI
- Receipt OCR (placeholder service exists, not integrated)
- Multi-device sync
- User accounts / login servers

A local JSON export/import helper (`BackupService`) exists in code but is not exposed in the Settings UI.

---

## License

This project is provided as-is for personal and educational use. See repository settings for license details if applicable.

---

## Author

**Thanoj Buddhima**

- Repository: [github.com/ThanojBuddhima/expenseAPK](https://github.com/ThanojBuddhima/expenseAPK)
- **Download latest APK:** [app-release.apk](https://github.com/ThanojBuddhima/expenseAPK/releases/latest/download/app-release.apk)
- Issues & feature requests: [GitHub Issues](https://github.com/ThanojBuddhima/expenseAPK/issues)
