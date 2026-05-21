# 📱 Sub Manager

<p align="center">
  <img src="assets/images/final_logo_fixed.png" alt="Sub Manager Logo" width="160" height="160" />
</p>

<p align="center">
  <strong>A sleek, cross-platform Flutter application designed to track, organize, and optimize recurring subscriptions and bills.</strong>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-%E2%9C%94-02569B?logo=flutter&style=flat-square" alt="Flutter Compatible" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-%E2%9C%94-0175C2?logo=dart&style=flat-square" alt="Dart Compatible" /></a>
  <a href="CHANGELOG.md"><img src="https://img.shields.io/badge/Version-1.0.0-success?style=flat-square" alt="Version 1.0.0" /></a>
  <img src="https://img.shields.io/badge/Platforms-Android%20|%20iOS%20|%20Web%20|%20Desktop-blue?style=flat-square" alt="Platform Support" />
</p>

---

## 🌟 Overview

**Sub Manager** simplifies your digital life by giving you complete control over your recurring costs. Keep track of when payments are due, how much you are spending, and analyze your subscriptions across platforms with a gorgeous, high-fidelity user interface.

## ✨ Key Features

- **📂 Comprehensive Subscription Tracking:** Create, read, update, and delete subscriptions. Categorize each item with custom names, precise amounts, flexible billing cycles, and next-due dates.
- **📅 Billing Calendar & Intelligent Reminders:** Visualize all upcoming bills on a timeline and receive local notifications before a subscription is charged so you never pay for an forgotten service.
- **📥 Robust Data Portability:** Securely export your local subscription data for backups or manual transfer to another device.
- **🎨 Polished Modern UI:** Clean visual design built around readability, micro-animations, and fluid transitions.
- **💻 True Multi-Platform:** Fully optimized for **Android, iOS, Web, Windows, macOS, and Linux**.

---

## 🚀 Release History & Changelog

### **Latest Stable Release: v1.0.0 (Initial Public Release)**
This release marks the first stable public launch of Sub Manager. It provides a complete set of features to keep track of recurring payments without any cloud dependencies.

> [!NOTE]
> For a full list of additions, bug fixes, performance improvements, and upgrade notes, refer to the [CHANGELOG.md](file:///d:/Akshit/Projects/Sub%20manager/CHANGELOG.md).

---

## 🛠️ Technology Stack

* **Framework:** [Flutter](https://flutter.dev) (Stable Channel)
* **Language:** [Dart](https://dart.dev)
* **Local Storage & Sync:** SQLite / Shared Preferences for offline-first capabilities
* **Notifications:** Local notifications scheduler
* **Integrations:** Env-driven API and currency converters

---

## 🚦 Getting Started

### Prerequisites

Before building or running the project, make sure you have:
* The [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (Stable version `^3.11.1` recommended).
* Appropriate platform tools set up:
  * **Android:** Android Studio and Android SDK / Build Tools.
  * **iOS / macOS:** Xcode and CocoaPods (on macOS).
  * **Windows / Linux:** Desktop build toolchains.

### Installation & Run

1. **Clone the repository and navigate to the project directory:**
   ```bash
   cd "Sub manager"
   ```

2. **Retrieve all Dart package dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables:**
   Rename `.env.example` to `.env` in the root folder and fill in the necessary keys.

4. **Launch the Application:**
   Run the app on a connected emulator, simulator, or physical device:
   ```bash
   flutter run
   ```

5. **Build Production Release Artifacts:**
   * **Android (APK):**
     ```bash
     flutter build apk --release
     ```
   * **iOS (IPA):**
     ```bash
     flutter build ipa --release
     ```
   * **Web:**
     ```bash
     flutter build web --release
     ```

---

## 📁 Project Structure

```text
├── android/          # Android native platform project and configurations
├── ios/              # iOS native platform project and configurations
├── web/              # Web platform build files and entrypoints
├── windows/          # Windows desktop platform project
├── macos/            # macOS desktop platform project
├── linux/            # Linux desktop platform project
├── assets/           # Bundled assets (final logo, images, fonts)
├── test/             # Unit, widget, and integration test suites
└── lib/              # Core Dart application source code
    ├── models/       # Data representation schemas
    ├── screens/      # Application screens and state views
    ├── services/     # API, storage, and notification services
    ├── utils/        # Helper files and utilities
    └── widgets/      # Reusable UI component modules
```

---

## 🧪 Testing & Code Standards

Keep the codebase clean, readable, and error-free:

* **Run Tests:** Verify all widget and business logic tests pass:
  ```bash
  flutter test
  ```
* **Format Code:** Automatically clean up styling and whitespace:
  ```bash
  flutter format .
  ```
* **Linting:** Analyze code using our customized `analysis_options.yaml` configuration:
  ```bash
  flutter analyze
  ```

---

## 🤝 Contributing

Contributions make the open-source community an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

This project is currently distributed without an explicit license. If you intend to use this code in a public fork, please add an appropriate license file (e.g., MIT, Apache 2.0).

---

## 📬 Contact & Support

For questions, issues, bug reports, or feature requests, feel free to open a [GitHub Issue](https://github.com/Akshit2004/Sub-manager/issues) or reach out directly to the project maintainers.
