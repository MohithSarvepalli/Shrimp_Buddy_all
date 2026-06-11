# Shrimp Buddy — Android (Kotlin + Jetpack Compose)

Native Android app for the Shrimp Buddy aquaculture management platform.

## Quick Setup

### 1. Set your backend URL
Open `app/src/main/java/com/shrimpbuddy/config/APIConfig.kt` and update:

```kotlin
// Android emulator → 10.0.2.2 resolves to host localhost
const val BASE_URL = "http://10.0.2.2:8085/api/v1/"
// Physical device → use your computer's local IP, e.g.:
// const val BASE_URL = "http://192.168.x.x:8085/api/v1/"
```
> Note: The trailing slash is required for Retrofit.

### 2. Open in Android Studio
- Open the `ShrimpBuddy-Android` folder in Android Studio Hedgehog (2023.1.1+)
- Let Gradle sync complete
- Run on an emulator (API 26+) or physical device

### 3. Minimum requirements
- Android API 26+ (Android 8.0)
- Android Studio Hedgehog or newer
- Kotlin 1.9+

---

## Project Structure

```
app/src/main/java/com/shrimpbuddy/
├── config/
│   └── APIConfig.kt          ← BASE_URL and all endpoint paths
├── models/
│   └── Models.kt             ← All data classes
├── network/
│   ├── APIService.kt         ← Retrofit interface (all endpoints)
│   └── RetrofitClient.kt     ← OkHttp + Retrofit setup + TokenManager
├── ui/
│   ├── theme/
│   │   └── Theme.kt          ← Material3 color scheme + design tokens
│   ├── navigation/
│   │   └── NavGraph.kt       ← App shell, bottom nav, screen routing
│   └── screens/
│       ├── auth/             ← Login, Register, Forgot Password
│       ├── dashboard/        ← Dashboard
│       ├── ponds/            ← Ponds list, add pond, pond detail (4 subtabs)
│       ├── ops/              ← Feed, Chemicals, Sampling, Water Quality
│       ├── finance/          ← Finance, Harvest, Market, Reports
│       └── staff/            ← Staff Directory, Audit Log, Settings
├── MainActivity.kt
└── ShrimpBuddyApplication.kt
```

---

## Dependencies (in build.gradle.kts)

| Library | Purpose |
|---------|---------|
| Jetpack Compose BOM | UI framework |
| Material3 | Design system |
| Retrofit 2.9 | HTTP client |
| OkHttp 4.12 + Logging Interceptor | Network layer |
| Gson Converter | JSON parsing |
| Coroutines 1.7 | Async/await |
| Navigation Compose | Screen navigation |

---

## Authentication

Tokens are stored in `SharedPreferences` via `TokenManager`. All API requests
automatically include:

```
Authorization: Bearer <token>
Content-Type: application/json
```

Same REST API contract as the iOS app — see `ShrimpBuddy-iOS/README.md` for
the full endpoint table.

---

## Production checklist

- [ ] Update `BASE_URL` in `APIConfig.kt`
- [ ] Set `minifyEnabled = true` and add ProGuard rules for Retrofit/Gson
- [ ] Configure `network_security_config.xml` for HTTPS pinning
- [ ] Replace placeholder `ic_launcher` icons with your app icon
- [ ] Set your `applicationId` to your Play Store package name
- [ ] Add proper error logging (e.g., Firebase Crashlytics)
