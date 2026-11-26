# SETUP.md — ProntoChat Next.js Admin Prototype

Running checklist of every public configuration input and hosting requirement.
Updated as implementation progresses.

---

## Configuration Inputs Checklist

### 1. Firebase Public Web Config
- [x] **API Key**: `AIzaSyCoj4FoCQR7sZp4SRIgyy4hT87Qy7Hpoho`
  - Where found: `lib/firebase_options.dart:44`
  - Configured in: `NEXT_PUBLIC_FIREBASE_API_KEY`
- [x] **Project ID**: `prontochat-3b974`
  - Where found: `lib/firebase_options.dart:47` & `.firebaserc:3`
  - Configured in: `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
- [x] **Auth Domain**: `prontochat-3b974.firebaseapp.com`
  - Where found: `lib/firebase_options.dart:48`
  - Configured in: `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
- [x] **Storage Bucket**: `prontochat-3b974.firebasestorage.app`
  - Where found: `lib/firebase_options.dart:49`
  - Configured in: `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
- [x] **Messaging Sender ID**: `326896452261`
  - Where found: `lib/firebase_options.dart:46`
  - Configured in: `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
- [x] **App ID**: `1:326896452261:web:a6a19791340662f6ed434c`
  - Where found: `lib/firebase_options.dart:45`
  - Configured in: `NEXT_PUBLIC_FIREBASE_APP_ID`
- [x] **Measurement ID**: `G-KFXW4WLR4L`
  - Where found: `lib/firebase_options.dart:50`
  - Configured in: `NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID`

---

### 2. Cloudinary Config (Public)
- [x] **Cloud Name**: `dj4miyael`
  - Where found: `CLOUDINARY_SETUP.md:10` and `example.env:14`
  - Configured in: `NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME`
- [x] **Named Transformation `logo_sm`**: `128px fit` (`t_logo_sm`)
  - Where found: `CLOUDINARY_SETUP.md:64-66`
- [x] **Named Transformation `logo_lg`**: `512px fit` (`t_logo_lg`)
  - Where found: `CLOUDINARY_SETUP.md:67-69`
- [x] **Strict Transformations status**: `ON`
  - Delivery URLs use strict named transformations: `https://res.cloudinary.com/<cloudName>/image/upload/t_<transformation>/<key>`

---

### 3. Flutter Web Routes (Hash Routing)
- [x] **Messaging Route**: `/#/home`
  - Where found: `lib/router/app_router.dart:113-115, 306`
  - Configured in: `NEXT_PUBLIC_FLUTTER_MESSAGING_PATH`
- [x] **Admin Dashboard Route**: `/#/admin/dashboard`
  - Where found: `lib/router/app_router.dart:126-128, 304`
  - Configured in: `NEXT_PUBLIC_FLUTTER_ADMIN_PATH`
- [x] **Legacy Onboarding Route**: `/#/admin/onboarding`
- [x] **Legacy Notices & Groups Route**: `/#/admin/notices`
- [x] **Legacy Brand & Customization Route**: `/#/admin/brand`

---

### 4. Hosting & Assembly Configuration
- [x] **Firebase Hosting Target**: Default hosting site for `prontochat-3b974`
- [x] **Assembly Directory**: `public_deploy/`
  - Root: Flutter Web SPA (`build/web/*`)
  - Subdirectory: `/admin/` contains Next.js static export (`admin_web/out/*`)
- [x] **Hosting Rewrites**:
  - `/admin/**` $\rightarrow$ `/admin/index.html`
  - `/**` $\rightarrow$ `/index.html`

---

### 5. Pending Account Inputs
- [x] All required configuration values discovered from existing codebase and configured.
- [ ] Production Firebase Hosting deployment target confirmation (Prototype tested locally in emulator).

