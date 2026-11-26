import { describe, it, expect } from "vitest";
import fs from "fs";
import path from "path";
import { bannedWriteOperation } from "@/lib/firebase/db-read-only";

describe("Strict Read-Only Data Access Enforcement", () => {
  it("bannedWriteOperation throws a violation error", () => {
    expect(() => bannedWriteOperation()).toThrowError(
      /VIOLATION: ProntoChat Admin Prototype is strictly READ-ONLY/
    );
  });

  it("ensures zero Firestore write functions exist in admin application source code", () => {
    const bannedPatterns = [
      /\bsetDoc\s*\(/,
      /\bupdateDoc\s*\(/,
      /\bdeleteDoc\s*\(/,
      /\baddDoc\s*\(/,
      /\brunTransaction\s*\(/,
      /\bwriteBatch\s*\(/,
    ];

    const searchDirs = [
      path.resolve(__dirname, "../app"),
      path.resolve(__dirname, "../components"),
      path.resolve(__dirname, "../lib"),
      path.resolve(__dirname, "../types"),
    ];

    function scanDirectory(dir: string): string[] {
      const files: string[] = [];
      if (!fs.existsSync(dir)) return files;
      const entries = fs.readdirSync(dir, { withFileTypes: true });

      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          files.push(...scanDirectory(fullPath));
        } else if (entry.isFile() && (entry.name.endsWith(".ts") || entry.name.endsWith(".tsx"))) {
          files.push(fullPath);
        }
      }
      return files;
    }

    const allFiles = searchDirs.flatMap(scanDirectory);
    expect(allFiles.length).toBeGreaterThan(0);

    const violations: { file: string; match: string }[] = [];

    for (const file of allFiles) {
      // Exclude seed script which is meant exclusively for emulator population
      if (file.includes("seed_emulator.ts")) continue;

      const content = fs.readFileSync(file, "utf-8");
      for (const pattern of bannedPatterns) {
        if (pattern.test(content)) {
          violations.push({
            file: path.relative(path.resolve(__dirname, ".."), file),
            match: pattern.toString(),
          });
        }
      }
    }

    expect(
      violations,
      `Banned Firestore write call(s) discovered in read-only admin app: ${JSON.stringify(
        violations,
        null,
        2
      )}`
    ).toEqual([]);
  });
});

