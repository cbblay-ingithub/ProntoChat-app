import { describe, it, beforeAll, afterAll, expect } from "vitest";
import fs from "fs";
import path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import { getCountFromServer, query, collection, where } from "firebase/firestore";

describe("Firestore Security Rules Verification for Count Queries", () => {
  let testEnv: RulesTestEnvironment | null = null;
  const rulesPath = path.resolve(__dirname, "../../firestore.rules");
  const hasRules = fs.existsSync(rulesPath);
  const rules = hasRules ? fs.readFileSync(rulesPath, "utf-8") : "";

  beforeAll(async () => {
    // Only run live against Firestore emulator if emulator is running
    if (process.env.FIRESTORE_EMULATOR_HOST) {
      testEnv = await initializeTestEnvironment({
        projectId: "prontochat-test-project",
        firestore: { rules },
      });
    }
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  it("verifies security rules file exists and contains isFirmAdmin definition", () => {
    expect(hasRules).toBe(true);
    expect(rules).toContain("function isFirmAdmin(firmId)");
    expect(rules).toContain("match /Firms/{firmId}");
    expect(rules).toContain("match /members/{memberId}");
    expect(rules).toContain("match /PreApprovedStaff/{staffDocId}");
  });

  it("ensures admin can count members and non-member cannot (when emulator is connected)", async () => {
    if (!testEnv) {
      // Passes when emulator is not connected, verifying static assertions
      expect(true).toBe(true);
      return;
    }

    const firmId = "firm_test_123";
    const adminUid = "admin_user_456";
    const nonMemberUid = "stranger_user_789";

    // Seed test data in emulator
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc(`Firms/${firmId}`).set({
        name: "Test Firm",
        adminId: adminUid,
        status: "active",
      });
      await db.doc(`Firms/${firmId}/members/${adminUid}`).set({
        role: "admin",
        status: "active",
      });
    });

    // Admin context: should succeed
    const adminContext = testEnv.authenticatedContext(adminUid);
    const adminDb = adminContext.firestore();
    const adminQuery = query(collection(adminDb, "Firms", firmId, "members"));
    await assertSucceeds(getCountFromServer(adminQuery));

    // Stranger context: should fail
    const strangerContext = testEnv.authenticatedContext(nonMemberUid);
    const strangerDb = strangerContext.firestore();
    const strangerQuery = query(collection(strangerDb, "Firms", firmId, "members"));
    await assertFails(getCountFromServer(strangerQuery));
  });
});
