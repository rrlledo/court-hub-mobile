# Court Hub Mobile

Initial Flutter source implementation for existing Court Hub accounts. Uses Riverpod for dependency injection, Dio for the Laravel API, GoRouter for authenticated navigation, and secure storage for access tokens.

## First release scope

- Sign-in with optional authenticator code; forgot-password request.
- Player self-registration: search facilities that have opened registration, select one, create an account, and receive an email-verification link before booking or starting a payment.
- Secure token persistence, session restoration, expired-session handling, and server-side logout.
- Identity and role labels obtained from `/auth/me` for all seven roles.
- Personal booking history with pagination and refresh.
- Player rental self-service: view only equipment currently or previously assigned to the signed-in player, including status, quantity, and due date.
- Staff rental operations: select a player and inventory item, issue equipment, extend a due date, receive a return, or close a rental with a damage fee.
- Player membership self-service: browse active facility plans, purchase or renew through PayMongo checkout or the local Xendit simulation, track pending/active status, remaining sessions, and a membership card after verified payment.
- Staff QR check-in: camera scanning and manual-code fallback for confirmed bookings and active membership cards, with tenant-scoped server validation. See `../docs/STAFF_CHECK_IN.md`.
- Coach and event-organizer workspaces: coaches can view assigned sessions and complete or cancel them; organizers can create facility-branch tournaments, register or cancel players, schedule court matches, and record results. See `../docs/ROLE_WORKSPACES.md`.
- Court-owner and facility-manager operations workspace: confirm or cancel today's reservations, manage facility registration, branches, courts, base prices, operating hours, and staff accounts. Court owners can also update staff roles.
- Owner and facility-manager reporting: select a date range to review operational totals, revenue, occupancy, peak hours, court use, memberships, coaching, tournaments, rentals, and refunds.
- Front Desk workspace: review today's facility-wide bookings, create walk-in reservations, confirm or cancel active bookings, and open the QR check-in scanner.
- Super Admin workspace: review platform-wide tenant and usage totals, inspect tenant accounts, suspend or reactivate tenants, edit tenant settings, and revoke a tenant user's sessions.
- PayMongo booking and membership checkout (GCash/Maya/card), external browser handoff, resume/manual status verification, payment receipt reference, and retry/review/expiry states. When local Xendit simulation is enabled by the API, it appears as an in-app simulated provider and never contacts a payment service. See `../docs/PAYMENTS.md` for setup.
- Reschedule upcoming active bookings from My Bookings. Choose a new time, check availability, and confirm. The same court, price, and original hold deadline are retained. Price-changing moves require assistance from the facility. The API enforces ownership, court locking, overlaps, closures, hours, and maintenance before saving; dates use UTC at the API boundary.
- Cancellation of upcoming active bookings, with confirmation and API ownership enforcement. Paid bookings require a separate refund arrangement; cancellation does not issue a refund.
- Booking creation: facility/branch/active-court selection, device-local date/time pickers sent as UTC, availability lookup, server-validated reservation, and an unpaid hold receipt with amount and expiry. Access from the Home or Bookings tab using **Book a court**.
- Notification inbox with pagination, refresh, and mark-as-read.
- Firebase Cloud Messaging registration on sign-in and token refresh, with device removal on logout. See `../docs/PUSH_NOTIFICATIONS.md`.
- Foreground FCM notifications appear as an in-app message with an Open action. System-notification taps and cold-start notifications route the signed-in user to the relevant booking, membership, coaching, tournament, operations, or inbox screen.
- Profile name editing.
- Loading, empty, error, and retry states.

Flutter browser and Windows runners are included alongside Android and iOS. Browser builds use responsive Material layouts and can be installed as a PWA. Windows uses the same role workspaces with manual QR entry; Firebase push registration is intentionally disabled for browser and Windows targets until their Firebase setup is supplied.

## Role-based user guides

Step-by-step mobile and web guides for Super Admin, Court Owner, Facility Manager, Front Desk, Coach, Event Organizer, and Player are in [`../docs/user-guides/README.md`](../docs/user-guides/README.md). Use the guide that matches the role shown after sign-in.

## API base URLs

| Target | Base URL |
| --- | --- |
| Local browser and Windows app | `http://127.0.0.1:8000/api/v1` |
| Android emulator | `http://10.0.2.2:8000/api/v1` |
| Staging | `https://api.staging.example.com/api/v1` (replace with the deployed hostname) |
| Production | `https://api.example.com/api/v1` (replace with the deployed hostname) |

## Setup on Windows

Install Flutter and the Android toolchain: https://docs.flutter.dev/install

From this directory:

```powershell
./scripts/bootstrap.ps1
flutter doctor
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

The default URL targets a Laravel server on the Android emulator host. Start the existing backend before signing in. Physical devices need a reachable host address or HTTPS development endpoint. Never put tokens or provider secrets in dart defines. Release builds must use an HTTPS API URL.

## Local, staging, and production environments

Flutter uses `--dart-define-from-file`, not `.env` files. Run locally with `flutter run --dart-define-from-file=config/local.json`. Use `config/staging.json` for browser, Windows, or staging-device builds, and `config/production.json` for release builds after replacing the placeholder API URL with the deployed HTTPS endpoint. These files contain only public `API_BASE_URL` values; do not add credentials, tokens, payment secrets, or signing passwords. See [`../docs/ENVIRONMENTS.md`](../docs/ENVIRONMENTS.md) for the complete process and deployment requirements.

Before distributing a live build, follow [`../docs/PRODUCTION_LAUNCH_REQUIREMENTS.md`](../docs/PRODUCTION_LAUNCH_REQUIREMENTS.md) for Firebase/APNs and store-account setup, current pricing, signing, production account requirements, and browser/Windows push-notification limitations.

The repository now includes generated Android and iOS runners. Android release permissions for internet, camera scanning, and notifications are declared. Before a device build, place the Firebase-generated `google-services.json` in `android/app/` and `GoogleService-Info.plist` in `ios/Runner/`; both are ignored by Git. The Android Google Services plugin is configured and therefore Android builds correctly fail until `google-services.json` is present. Configure Android release signing in `android/key.properties` before distributing a release. For local HTTP testing, enable cleartext traffic only in an Android debug manifest. iOS builds require macOS/Xcode; configure camera usage text and Keychain entitlements for flutter_secure_storage and use HTTPS rather than broad transport-security exceptions.

## Verification

```powershell
dart format lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
flutter build web --dart-define=API_BASE_URL=https://api.example.com/api/v1
flutter build windows --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

For a release candidate, use an HTTPS API endpoint and a signed Android bundle after adding Firebase configuration:

```powershell
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

Run the release preflight before building a candidate. It checks both Firebase files, enforces an HTTPS API URL, runs analysis and tests, and optionally builds the signed Android bundle:

```powershell
./scripts/release-preflight.ps1 -ApiBaseUrl https://api.example.com/api/v1 -BuildAndroidRelease
```

Create `android/key.properties` outside version control with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. The release Gradle configuration uses this file when present; otherwise local release builds use the debug key and must not be distributed.

Device acceptance: valid/invalid sign-in, 2FA, restart with saved session, offline restore/retry, expired token, pagination, empty history/inbox, mark-read, profile save, logout/restart, and switching accounts without retaining previous records.

## Backend dependencies and remaining mobile work

Player registration requires the facility owner or manager to open registration in the web facility-management screen. The app uses the public `GET /api/v1/registration/facilities` and `POST /api/v1/auth/register-player` endpoints; a player account is tied to its selected facility and receives only player-safe API access. Email verification is required before it can create bookings or payment intents.

Players see personal booking history, memberships, rentals, and user-scoped notifications. The **Rentals** tab displays only equipment assigned to the signed-in account and directs extensions and returns to the front desk. Court owners, facility managers, and front-desk users also receive **Rental desk** to issue equipment to a selected player, manage returns and extensions, and record damage fees. Payment notifications open the matching booking or membership payment-status screen. Role labels are presentation only; authorization belongs in the API.

Booking creation uses the implemented `GET /api/v1/booking-facilities` read-only, authenticated tenant-scoped discovery route. Facility management permissions are unchanged. The maintenance model table mapping was corrected so availability and reservation creation can run against the existing migration.

Payment-provider acceptance and device testing are still required before a real-provider launch; automated backend tests and local Xendit use simulations. Follow `../docs/PUSH_NOTIFICATIONS.md` for Firebase and `../docs/PAYMENTS.md` for the provider and simulation checklist.


