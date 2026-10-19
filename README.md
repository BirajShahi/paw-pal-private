# PawPal

PawPal is a Flutter app that connects pet owners with pet sitters. Owners keep pet profiles, browse services, request bookings, and ask the AI Service Finder for a service recommendation. Sitters manage their profile, services, and booking requests.

Android is the main platform. A web build is also supported.

## Features

- Email and password authentication for owners and sitters, using Supabase Auth
- Owner dashboard with pets, sitter discovery, a provider map, and bookings
- Sitter dashboard with profile, services, and booking requests
- Pet profiles, including coat type and medical, behaviour, and care notes
- Pet list and a pet details screen
- PawPal service catalogue and sitter service offerings
- Booking requests, owner booking history, and sitter accept, decline, and complete actions
- Simulated card payment placeholder
- AI Service Finder, which recommends services such as grooming or nail care
- Supabase database, authentication, and the `recommend-service` Edge Function

## Technology

- Flutter and Dart
- Supabase for authentication, the database, and Edge Functions
- Groq, called only from the Supabase Edge Function
- Riverpod for state management and dependency injection
- go_router for navigation

## Requirements

- Flutter SDK
- Android Studio
- Android SDK
- An Android emulator or a physical Android device
- Chrome, only if you want to run the optional web version

## Installation

```bash
flutter pub get
```

## Configuration

The app reads its Supabase connection from compile-time values. Do not commit real keys.

Required when you run or build the app:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY` (the publishable or anon key, not the service role key)

Example:

```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

The Groq key is not part of the Flutter app. Store `GROQ_API_KEY` as a Supabase Edge Function secret. The AI Service Finder calls the `recommend-service` function, and that function calls Groq.

## Running Android

List connected devices and emulators:

```bash
flutter devices
```

Run on the Android emulator or device:

```bash
flutter run
```

Pass the two `--dart-define` values from Configuration. In Android Studio or VS Code, select the Android emulator and add the same defines to the run configuration.

A debug APK can be built with:

```bash
flutter build apk --debug
```

## Running Web

```bash
flutter run -d chrome
```

Use the same Supabase `--dart-define` values.

## Testing

```bash
flutter test
```

## Static Analysis

```bash
flutter analyze
```

## Project Structure / Architecture

Screens stay thin. They read Riverpod providers, and those providers supply repositories.

```text
UI screens
  -> Riverpod providers / controllers
    -> Repositories
      -> Supabase Auth, database, and Edge Functions
        -> Groq for the AI Service Finder only
```

`ProviderScope` in `lib/main.dart` is the dependency injection container. Repository providers such as `authRepositoryProvider`, `petRepositoryProvider`, and `bookingRepositoryProvider` create each repository once and pass in the shared Supabase client. Widgets do not construct those repositories themselves.

Main folders under `lib/`:

- `core/` — theme, router, shared widgets, Supabase configuration
- `features/auth/` — login, registration, and roles
- `features/pets/` — pet list, details, and editing
- `features/bookings/` — booking requests and the payment placeholder
- `features/services/` — the service catalogue and sitter offerings
- `features/ai_recommendation/` — AI Service Finder
- `features/owner/` and `features/sitter/` — role dashboards

## Demonstration path

1. Start the app and log in as a pet owner.
2. Open the owner dashboard.
3. Open Pets to see the list.
4. Tap a pet to open Pet details.
5. Use the back button to return to the list.
6. Open Bookings, then AI Service Finder from Home.
7. Log out from the app bar.
