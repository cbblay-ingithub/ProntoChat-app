# Proposed Diffs & Configuration Patches

In accordance with **Decision 4** (*"DO NOT modify the Firestore security rules, the data model, or the Flutter code in this task. PROPOSE it with the exact diff and wait for my approval"*), the following diffs are formally proposed for user approval.

---

## 1. `firebase.json` — Hosting Rewrites & Emulator Configuration

### Purpose:
Enables same-origin hosting of Flutter Web at the root (`/`) and the Next.js static export at `/admin/**`. The `/admin/**` rewrite is placed **before** the Flutter SPA catch-all rewrite (`**`) so requests to `/admin` are handled by Next.js rather than being caught by Flutter's router.

### Proposed Diff:
```diff
--- firebase.json	(original)
+++ firebase.json	(proposed)
@@ -6,6 +6,29 @@
   "storage": {
     "rules": "storage.rules"
   },
+  "hosting": {
+    "public": "public_deploy",
+    "ignore": [
+      "firebase.json",
+      "**/.*",
+      "**/node_modules/**"
+    ],
+    "rewrites": [
+      {
+        "source": "/admin/**",
+        "destination": "/admin/index.html"
+      },
+      {
+        "source": "**",
+        "destination": "/index.html"
+      }
+    ]
+  },
+  "emulators": {
+    "auth": { "port": 9099 },
+    "firestore": { "port": 8080 },
+    "hosting": { "port": 5000 },
+    "ui": { "enabled": true, "port": 4000 }
+  },
   "flutter": {
     "platforms": {
       "android": {
```

---

## 2. Flutter Codebase — Direct Navigation to Next.js Admin Console

### 2.1 File: `lib/router/app_router.dart`
### Purpose:
When an authenticated Firm Admin logs in on Flutter Web, redirect them to the modern Next.js `/admin/` console rather than the legacy Flutter `AdminShell`. Also intercepts any web navigation to `/admin-dashboard` or `/admin/dashboard` to redirect to `/admin/`.

### Proposed Diff:
```diff
--- lib/router/app_router.dart	(original)
+++ lib/router/app_router.dart	(proposed)
@@ -10,6 +10,7 @@
 import 'package:flutter/foundation.dart';
 import 'package:flutter/material.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:universal_html/html.dart' as html;
 import 'package:go_router/go_router.dart';
 
@@ -301,7 +302,8 @@
 
       if (isAuthScreen) {
         if (kIsWeb && (role == 'admin' || role == 'super_admin')) {
-          return '/admin/dashboard';
+          html.window.location.href = '/admin/';
+          return null;
         }
         return '/home';
       }
@@ -319,6 +321,10 @@
       // Backward compatibility redirect for legacy admin dashboard path
       if (path == '/admin-dashboard') {
+        if (kIsWeb) {
+          html.window.location.href = '/admin/';
+          return null;
+        }
         return '/admin/dashboard';
       }
```

---

### 2.2 File: `lib/pages/employee/employee_profile_tab.dart`
### Purpose:
Adds a visible **"Open Admin Console"** action card to the Firm Admin's profile screen when signed in on Web, providing an intuitive link to `/admin/`.

### Proposed Diff:
```diff
--- lib/pages/employee/employee_profile_tab.dart	(original)
+++ lib/pages/employee/employee_profile_tab.dart	(proposed)
@@ -4,6 +4,8 @@
 import 'package:flutter/material.dart';
 import 'package:flutter/services.dart';
 import 'package:flutter_riverpod/flutter_riverpod.dart';
+import 'package:flutter/foundation.dart' show kIsWeb;
+import 'package:universal_html/html.dart' as html;
 
@@ -183,6 +185,27 @@
                 ),
 
                 const SizedBox(height: 28),
+
+                // ── Admin Console Quick Link (Admins on Web) ──────────────────
+                if (kIsWeb && (role == 'admin' || role == 'super_admin')) ...[
+                  Container(
+                    margin: const EdgeInsets.only(bottom: 16),
+                    decoration: BoxDecoration(
+                      gradient: const LinearGradient(
+                        colors: [Color(0xFF065F46), Color(0xFF047857)],
+                      ),
+                      borderRadius: BorderRadius.circular(16),
+                    ),
+                    child: ListTile(
+                      leading: const Icon(Icons.admin_panel_settings, color: Colors.white),
+                      title: const Text('Open Next.js Admin Console', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
+                      subtitle: const Text('Access staff directory, seat meters, and metrics', style: TextStyle(color: Colors.white70, fontSize: 12)),
+                      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
+                      onTap: () => html.window.location.href = '/admin/',
+                    ),
+                  ),
+                ],
 
                 // ── Firm Organization Card ───────────────────────────────────────
                 Container(
```

---

## 3. Firestore Security Rules & Indexes Audit

### 3.1 Security Rules (`firestore.rules`)
**Status: NO MODIFICATIONS NEEDED.**
The existing security rules enforce:
```rules
function isFirmAdmin(firmId) {
  return isSignedIn() &&
    exists(/databases/$(database)/documents/Firms/$(firmId)/members/$(request.auth.uid)) &&
    get(/databases/$(database)/documents/Firms/$(firmId)/members/$(request.auth.uid)).data.role in ['admin', 'super_admin'];
}
```
All dashboard queries are strictly firm-scoped and read-only. Server-side `count()` queries evaluate security rules per collection query and succeed because the signed-in admin's credentials satisfy `isFirmAdmin(firmId)` for `Memberships`, `PreApprovedStaff`, `departments`, `project_groups`, `notices`, `presence`, and `audit_log`.

### 3.2 Firestore Indexes (`firestore.indexes.json`)
**Status: NO MODIFICATIONS NEEDED.**
All 9 required composite indexes already exist:
1. `Memberships`: `firmId ASC, status ASC, role ASC`
2. `Memberships`: `firmId ASC, status ASC, joinedAt DESC`
3. `PreApprovedStaff`: `firmId ASC, status ASC, invitedAt DESC`
4. `PreApprovedStaff`: `firmId ASC, status ASC, codeExpiresAt ASC`
5. `project_groups`: `firmId ASC, status ASC, createdAt DESC`
6. `notices`: `firmId ASC, status ASC, createdAt DESC`
7. `audit_log`: `firmId ASC, timestamp DESC`
8. `presence`: `firmId ASC, date DESC`
9. `departments`: `firmId ASC, createdAt ASC`

Zero new composite indexes or backfills are needed.

