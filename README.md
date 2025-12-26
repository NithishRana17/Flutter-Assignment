# Logbook Lite ✈️

A modern, offline-first pilot logbook application built with Flutter. Track your flights, sync across devices, and get AI-powered flight analysis from Captain MAVE.

![Flutter](https://img.shields.io/badge/Flutter-3.10+-blue)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue)
![Supabase](https://img.shields.io/badge/Backend-Supabase-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## ✨ Features

- **Offline-First Architecture** - Work without internet, sync when online
- **Real-time Sync** - Instant updates across all your devices
- **Captain MAVE AI** - AI flight instructor powered by Google Gemini
- **Secure Authentication** - Email/password auth with Supabase
- **Analytics Dashboard** - Track your flying hours and progress
- **Cross-Platform** - Android, iOS, and Web support

---

## 🚀 Setup Steps

### Prerequisites

1. **Flutter SDK** (3.10.4 or higher)
   ```bash
   flutter --version
   ```

2. **Android Studio** or **VS Code** with Flutter extensions

3. **Android Emulator** or physical device

4. **Supabase Account** - [Create free account](https://supabase.com)

5. **Google AI Studio Account** - [Get API Key](https://aistudio.google.com/app/apikey)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd logbook_lite
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Create environment file**
   ```bash
   cp .env.example .env
   ```

4. **Configure `.env` file** (see Backend Configuration below)

5. **Generate app icons** (optional)
   ```bash
   dart run flutter_launcher_icons
   ```

---

## ▶️ How to Run the App

### Android Emulator
```bash
flutter run -d emulator-5554
```

### Web (Edge/Chrome)
```bash
flutter run -d edge
# or
flutter run -d chrome
```

### All Devices
```bash
flutter devices          # List available devices
flutter run -d <device>  # Run on specific device
```

### Hot Reload
- Press `r` for hot reload
- Press `R` for hot restart
- Press `q` to quit

---

## ⚙️ Backend Configuration

### Supabase Setup

1. **Create a new project** at [supabase.com](https://supabase.com)

2. **Run the database schema** - Execute the SQL from `supabase_schema.sql` in the Supabase SQL Editor

3. **Get your credentials** from Project Settings → API:
   - Project URL
   - Anon (public) key

4. **Update `lib/core/constants/app_constants.dart`**:
   ```dart
   class SupabaseConfig {
     static const String url = 'YOUR_SUPABASE_URL';
     static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
   }
   ```

### Environment Variables (.env)

Create a `.env` file in the project root:

```properties
# Gemini API Key for Captain MAVE AI
# Get yours from: https://aistudio.google.com/app/apikey
GEMINI_API_KEY=your_gemini_api_key_here
```

> ⚠️ **Important**: Never commit `.env` to version control. It's already in `.gitignore`.

### Required Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key for AI features | Yes |

---

## 📡 Offline Sync Explanation

### How It Works

Logbook Lite uses an **offline-first architecture** with smart sync:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Local Hive    │ ←→  │   Sync Engine   │ ←→  │    Supabase     │
│   (Offline DB)  │     │   (Smart Merge) │     │   (Cloud DB)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Key Features

1. **Local Storage (Hive)**
   - All data is stored locally first
   - App works 100% offline
   - Fast read/write operations

2. **Sync Status Tracking**
   - `pending` - Created/modified offline, needs sync
   - `synced` - Synchronized with cloud
   - `deleted` - Soft-deleted, pending cloud removal

3. **Smart Merge Logic**
   - Local changes preserved until synced
   - Remote synced data updates local entries
   - Conflict resolution: Local pending > Remote synced

4. **Real-time Updates**
   - Supabase Realtime subscription for instant sync
   - Changes on one device appear immediately on others
   - "Live" indicator shows connection status

### Sync Flow

```
1. User creates/edits flight → Saved locally (status: pending)
2. App detects internet → Syncs to Supabase (status: synced)
3. Other device receives realtime event → Updates local data
4. If offline → Changes queue until connection restored
```

---

## 🤖 How I Used AI Tools

### Development Environment

I developed this application using **Antigravity IDE** - an AI-powered development environment from **Google**, built on top of **VS Code**. This significantly accelerated the development process with intelligent code suggestions and AI-assisted debugging.

### AI Models Used

| Model | Usage |
|-------|-------|
| **Claude Opus 4.5** | Primary development - Used for most coding tasks, architecture decisions, debugging, and feature implementation |
| **Gemini 3 Pro** | Secondary model - Used when Claude token limits were reached |

### AI-Assisted Tasks

- 🏗️ **Architecture Design** - Offline-first patterns, state management structure
- 💻 **Code Generation** - UI components, services, providers
- 🐛 **Debugging** - Error analysis and fixes
- 📝 **Documentation** - README, code comments
- 🎨 **UI/UX** - Design suggestions, animations
- 🔧 **Configuration** - Supabase setup, environment configuration

### Privacy & Security Practices

> 🔐 **I ensured that sensitive data like API keys are NOT shared with AI tools to maintain privacy and security.**

- Environment variables (`.env`) were never exposed to AI
- Supabase credentials were configured manually
- API keys were handled through secure environment files
- `.gitignore` properly configured to exclude sensitive files

### Benefits of AI-Assisted Development

1. **Faster Development** - Reduced time spent on boilerplate code
2. **Better Code Quality** - AI suggestions improved patterns and practices
3. **Debugging Efficiency** - Quick identification and resolution of issues
4. **Learning** - Gained insights into best practices and new techniques

---

## 📁 Project Structure

```
lib/
├── app/                    # App configuration, routing
├── core/                   # Theme, constants, utilities
├── data/
│   ├── models/            # Data models (LogbookEntry, UserProfile)
│   └── services/          # Supabase, LocalStorage, Gemini services
├── presentation/
│   └── screens/           # UI screens (auth, home, logbook, AI)
└── providers/             # Riverpod state management
```

---

## 📄 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [Supabase](https://supabase.com) - Backend as a Service
- [Google Gemini](https://ai.google.dev) - AI capabilities
- [Antigravity IDE](https://www.jetbrains.com) - AI-powered development
- [Riverpod](https://riverpod.dev) - State management
