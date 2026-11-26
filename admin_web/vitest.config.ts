import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./test/setup.ts"],
    env: {
      NEXT_PUBLIC_FIREBASE_API_KEY: "AIzaSyCoj4FoCQR7sZp4SRIgyy4hT87Qy7Hpoho",
      NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN: "prontochat-3b974.firebaseapp.com",
      NEXT_PUBLIC_FIREBASE_PROJECT_ID: "prontochat-3b974",
      NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET: "prontochat-3b974.firebasestorage.app",
      NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID: "326896452261",
      NEXT_PUBLIC_FIREBASE_APP_ID: "1:326896452261:web:a6a19791340662f6ed434c",
      NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID: "G-KFXW4WLR4L",
      NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME: "dj4miyael",
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./"),
    },
  },
});
