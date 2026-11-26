/**
 * Firebase Client Initialization
 * Modular SDK, zero secret keys, public browser-only initialization.
 */

import { initializeApp, getApps, getApp, type FirebaseApp } from "firebase/app";
import { getAuth, connectAuthEmulator, type Auth } from "firebase/auth";
import { getFirestore, connectFirestoreEmulator, type Firestore } from "firebase/firestore";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
  measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
};

// Loud input alert protocol validation
export function validateFirebaseConfig(): { isValid: boolean; missing: string[] } {
  const required = [
    ["NEXT_PUBLIC_FIREBASE_API_KEY", firebaseConfig.apiKey],
    ["NEXT_PUBLIC_FIREBASE_PROJECT_ID", firebaseConfig.projectId],
    ["NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN", firebaseConfig.authDomain],
    ["NEXT_PUBLIC_FIREBASE_APP_ID", firebaseConfig.appId],
  ] as const;

  const missing = required
    .filter(([_, val]) => !val || val.includes("your_") || val.trim().length === 0)
    .map(([key]) => key);

  if (missing.length > 0) {
    const errorMsg = `<FIREBASE INPUT NEEDED: Public Firebase Web Config | lib/firebase_options.dart in Flutter project | ${missing.join(", ")}>`;
    console.error(errorMsg);
    return { isValid: false, missing };
  }

  return { isValid: true, missing: [] };
}

let app: FirebaseApp;
let auth: Auth;
let db: Firestore;

if (typeof window !== "undefined") {
  const { isValid, missing } = validateFirebaseConfig();
  if (!isValid && process.env.NODE_ENV !== "test") {
    console.warn(`[Firebase] Missing configuration values: ${missing.join(", ")}`);
  }

  app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
  auth = getAuth(app);
  db = getFirestore(app);

  // Connect to local emulators if configured
  if (process.env.NEXT_PUBLIC_USE_FIREBASE_EMULATOR === "true") {
    const authUrl = process.env.NEXT_PUBLIC_FIREBASE_AUTH_EMULATOR_URL || "http://127.0.0.1:9099";
    const firestoreHost = process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_HOST || "127.0.0.1";
    const firestorePort = Number(process.env.NEXT_PUBLIC_FIRESTORE_EMULATOR_PORT || 8080);

    try {
      connectAuthEmulator(auth, authUrl, { disableWarnings: true });
      connectFirestoreEmulator(db, firestoreHost, firestorePort);
      console.log(`[Firebase] Connected to local Auth (${authUrl}) & Firestore (${firestoreHost}:${firestorePort}) emulators`);
    } catch {
      // Emulator connection already established
    }
  }
} else {
  // SSR / build-time dummy stub
  app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
  auth = getAuth(app);
  db = getFirestore(app);
}

export { app, auth, db };

