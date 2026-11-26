/**
 * Seed Script for Local Firebase Emulator
 *
 * PRODUCTION GUARD:
 * Refuses to run unless FIRESTORE_EMULATOR_HOST or FIREBASE_EMULATOR_HUB is defined.
 * Cannot touch production Firestore.
 */

import { initializeApp } from "firebase/app";
import {
  getFirestore,
  connectFirestoreEmulator,
  doc,
  writeBatch,
  Timestamp,
} from "firebase/firestore";

// ── 1. Production Safety Guard ──────────────────────────────────────────────
const isEmulatorHostSet = !!process.env.FIRESTORE_EMULATOR_HOST;
const isEmulatorHubSet = !!process.env.FIREBASE_EMULATOR_HUB;

if (!isEmulatorHostSet && !isEmulatorHubSet) {
  console.error("\n==================================================================");
  console.error("FATAL: PRODUCTION SAFETY GUARD TRIGGERED");
  console.error("This seed script is restricted to local Firebase Emulators only.");
  console.error("Neither FIRESTORE_EMULATOR_HOST nor FIREBASE_EMULATOR_HUB was found.");
  console.error("To seed the emulator, run with:");
  console.error("  $env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'; npm run seed");
  console.error("==================================================================\n");
  process.exit(1);
}

const emulatorHost = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const [host, portStr] = emulatorHost.split(":");
const port = Number(portStr) || 8080;

console.log(`[Seed] Connecting to Firestore Emulator at ${host}:${port}...`);

const app = initializeApp({
  projectId: "prontochat-3b974",
  apiKey: "mock-api-key-for-emulator-seed",
});

const db = getFirestore(app);
connectFirestoreEmulator(db, host, port);

async function seed() {
  console.log("[Seed] Starting realistic data population for Acme Corporation...");

  const firmId = "firm_acme_corp";
  const adminUid = "admin_sarah";
  const now = new Date();

  // 1. Firm Document
  const firmRef = doc(db, "Firms", firmId);
  const batch1 = writeBatch(db);

  batch1.set(firmRef, {
    name: "Acme Global Dynamics",
    primaryColor: "#10B981",
    secondaryColor: "#295CB4",
    ownerUid: adminUid,
    adminId: adminUid,
    plan: "trial",
    status: "active",
    seatLimit: 150,
    seatCount: 124, // Slight desync from true active+invited to demonstrate out-of-sync alert
    termsAcceptedAt: Timestamp.fromDate(new Date(now.getTime() - 70 * 24 * 60 * 60 * 1000)),
    createdAt: Timestamp.fromDate(new Date(now.getTime() - 70 * 24 * 60 * 60 * 1000)),
    logo: {
      provider: "cloudinary",
      key: "prontochat/logos/acme_corp_main",
      kind: "image",
      w: 512,
      h: 512,
      bytes: 42100,
      format: "png",
    },
    showLastSeen: true,
    showReadReceipts: true,
    welcomeText: "Welcome to Acme Global Dynamics staff portal.",
  });

  // Admin Membership root document
  const adminMembershipRef = doc(db, "Memberships", adminUid);
  batch1.set(adminMembershipRef, {
    uid: adminUid,
    firmId,
    name: "Sarah Connor",
    email: "sarah@acme.com",
    role: "admin",
    status: "active",
    createdAt: Timestamp.fromDate(new Date(now.getTime() - 70 * 24 * 60 * 60 * 1000)),
    joinedAt: Timestamp.fromDate(new Date(now.getTime() - 70 * 24 * 60 * 60 * 1000)),
  });

  // Admin Users document
  const adminUserRef = doc(db, "Users", adminUid);
  batch1.set(adminUserRef, {
    name: "Sarah Connor",
    nameLower: "sarah connor",
    email: "sarah@acme.com",
    role: "admin",
    firmIds: [firmId],
    ownedFirmId: firmId,
    lastSeen: Timestamp.now(),
  });

  // Admin member document
  const adminMemberRef = doc(db, "Firms", firmId, "members", adminUid);
  batch1.set(adminMemberRef, {
    name: "Sarah Connor",
    role: "admin",
    status: "active",
    departmentId: "dept_exec",
    createdAt: Timestamp.fromDate(new Date(now.getTime() - 70 * 24 * 60 * 60 * 1000)),
    joinedAt: Timestamp.fromDate(new Date(now.getTime() - 70 * 24 * 60 * 60 * 1000)),
  });

  await batch1.commit();
  console.log("  ✓ Created Firm and Admin account");

  // 2. Departments (6 departments, 2 without heads)
  const departments = [
    { id: "dept_eng", name: "Engineering", headUid: "lead_alex" },
    { id: "dept_sales", name: "Enterprise Sales", headUid: "lead_elena" },
    { id: "dept_design", name: "Product Design", headUid: "lead_marcus" },
    { id: "dept_mktg", name: "Brand Marketing", headUid: null }, // NO HEAD
    { id: "dept_legal", name: "Legal & Compliance", headUid: null }, // NO HEAD
    { id: "dept_ops", name: "Global Operations", headUid: "lead_diana" },
  ];

  const batch2 = writeBatch(db);
  for (const dept of departments) {
    const dRef = doc(db, "Firms", firmId, "departments", dept.id);
    batch2.set(dRef, {
      name: dept.name,
      headUid: dept.headUid,
      status: "active",
      createdBy: adminUid,
      conversationId: `conv_${dept.id}`,
      createdAt: Timestamp.fromDate(new Date(now.getTime() - 65 * 24 * 60 * 60 * 1000)),
    });
  }
  await batch2.commit();
  console.log("  ✓ Created 6 departments (2 without heads)");

  // 3. Members (~120 staff members across 10 weeks)
  const firstNames = ["James", "Emma", "Liam", "Olivia", "Noah", "Sophia", "Lucas", "Mia", "Ethan", "Ava", "Leo", "Isabella", "Mason", "Harper", "Oliver", "Amelia"];
  const lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Garcia", "Rodriguez", "Wilson", "Martinez", "Anderson", "Taylor", "Thomas"];

  const batchSize = 100;
  let currentBatch = writeBatch(db);
  let batchCount = 0;

  for (let i = 1; i <= 118; i++) {
    const uid = `staff_${i.toString().padStart(3, "0")}`;
    const fn = firstNames[i % firstNames.length];
    const ln = lastNames[i % lastNames.length];
    const name = `${fn} ${ln}`;
    const email = `${fn.toLowerCase()}.${ln.toLowerCase()}${i}@acme.com`;

    // Role assignment: ~6 admins, ~15 leads, remaining employees
    let role = "employee";
    if (i <= 6) role = "admin";
    else if (i <= 21) role = "lead";

    // Status: 108 active, 4 pending, 6 revoked
    let status = "active";
    if (i >= 113) status = "revoked";
    else if (i >= 109) status = "pending";

    // Department: assign to 6 depts, or unassigned (no department)
    let deptId: string | null = departments[i % departments.length].id;
    if (i % 8 === 0) deptId = null; // Unassigned bucket

    // Join date spread over 10 weeks
    const weekIndex = i % 10;
    const daysAgo = weekIndex * 7 + (i % 6);
    const joinedAt = status !== "pending" ? Timestamp.fromDate(new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000)) : null;
    const createdAt = Timestamp.fromDate(new Date(now.getTime() - (daysAgo + 2) * 24 * 60 * 60 * 1000));
    const revokedAt = status === "revoked" ? Timestamp.fromDate(new Date(now.getTime() - (i % 5) * 24 * 60 * 60 * 1000)) : null;

    const mRef = doc(db, "Firms", firmId, "members", uid);
    currentBatch.set(mRef, {
      name,
      role,
      status,
      departmentId: deptId,
      createdAt,
      ...(joinedAt ? { joinedAt } : {}),
      ...(revokedAt ? { revokedAt } : {}),
      avatarUrl: `https://api.dicebear.com/7.x/avataaars/png?seed=${encodeURIComponent(name)}`,
    });

    // Also populate Presence for active members
    if (status === "active") {
      const presenceDaysAgo = i % 9; // ~85% in past 7 days
      const presRef = doc(db, "Firms", firmId, "presence", uid);
      currentBatch.set(presRef, {
        uid,
        lastSeenAt: Timestamp.fromDate(new Date(now.getTime() - presenceDaysAgo * 24 * 60 * 60 * 1000)),
      });
    }

    batchCount += 2;
    if (batchCount >= batchSize) {
      await currentBatch.commit();
      currentBatch = writeBatch(db);
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await currentBatch.commit();
  }
  console.log("  ✓ Created 118 team members with presence records");

  // 4. PreApprovedStaff (Invites: code pending, expired, stale, claimed)
  const batch3 = writeBatch(db);

  // Expiring soon (<5 min)
  batch3.set(doc(db, "Firms", firmId, "PreApprovedStaff", "invite_expiring_1"), {
    email: "cynthia.vance@partner.com",
    name: "Cynthia Vance",
    code: "774912",
    codeExpiresAt: Timestamp.fromDate(new Date(now.getTime() + 3 * 60 * 1000)),
    codeUpdatedAt: Timestamp.now(),
    status: "invited",
    role: "employee",
    departmentId: "dept_sales",
    invitedAt: Timestamp.now(),
  });

  // Stale invite (>7 days)
  batch3.set(doc(db, "Firms", firmId, "PreApprovedStaff", "invite_stale_1"), {
    email: "derek.morgan@contractor.com",
    name: "Derek Morgan",
    code: "482019",
    codeExpiresAt: Timestamp.fromDate(new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000)),
    codeUpdatedAt: Timestamp.fromDate(new Date(now.getTime() - 8 * 24 * 60 * 60 * 1000)),
    status: "invited",
    role: "employee",
    departmentId: "dept_eng",
    invitedAt: Timestamp.fromDate(new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000)),
  });

  // Normal valid pending codes
  for (let p = 1; p <= 6; p++) {
    batch3.set(doc(db, "Firms", firmId, "PreApprovedStaff", `invite_pending_${p}`), {
      email: `candidate.${p}@recruiting.com`,
      name: `Candidate ${p}`,
      code: `3948${p}1`,
      codeExpiresAt: Timestamp.fromDate(new Date(now.getTime() + 4 * 60 * 1000)),
      codeUpdatedAt: Timestamp.now(),
      status: "invited",
      role: "employee",
      departmentId: "dept_eng",
      invitedAt: Timestamp.now(),
    });
  }

  // Joined invites (historical funnel conversion)
  for (let j = 1; j <= 24; j++) {
    batch3.set(doc(db, "Firms", firmId, "PreApprovedStaff", `invite_joined_${j}`), {
      email: `onboarded.${j}@acme.com`,
      name: `Onboarded Staff ${j}`,
      status: "joined",
      role: "employee",
      departmentId: "dept_eng",
      invitedAt: Timestamp.fromDate(new Date(now.getTime() - (j + 5) * 24 * 60 * 60 * 1000)),
      joinedAt: Timestamp.fromDate(new Date(now.getTime() - (j + 4) * 24 * 60 * 60 * 1000)),
      uid: `staff_0${j}`,
    });
  }

  await batch3.commit();
  console.log("  ✓ Created PreApprovedStaff in all states (expiring, stale, joined)");

  // 5. Projects (Active & Archived, including 1 revoked owner)
  const batch4 = writeBatch(db);
  const projects = [
    { id: "proj_falcon", name: "Project Falcon (Core App)", ownerUid: "staff_002", status: "active" },
    { id: "proj_shield", name: "Project Shield (Security Review)", ownerUid: "staff_004", status: "active" },
    { id: "proj_revoked", name: "Project Phoenix (Migration)", ownerUid: "staff_115", status: "active" }, // staff_115 is revoked!
    { id: "proj_legacy", name: "Legacy Portal Sunset", ownerUid: "staff_003", status: "archived" },
  ];

  for (const proj of projects) {
    batch4.set(doc(db, "Firms", firmId, "projects", proj.id), {
      name: proj.name,
      ownerUid: proj.ownerUid,
      participantIds: [proj.ownerUid, adminUid],
      status: proj.status,
      conversationId: `conv_${proj.id}`,
      createdAt: Timestamp.now(),
    });
  }

  // 6. Notices & Policy Index
  batch4.set(doc(db, "Firms", firmId, "noticeIndex", "notice_policy_1"), {
    authorId: adminUid,
    authorName: "Sarah Connor",
    type: "policy",
    audienceKeys: ["firm"],
    status: "published",
    version: 2,
    createdAt: Timestamp.fromDate(new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000)),
  });

  batch4.set(doc(db, "Firms", firmId, "noticeIndex", "notice_urgent_1"), {
    authorId: adminUid,
    authorName: "Sarah Connor",
    type: "urgent",
    audienceKeys: ["firm"],
    status: "published",
    version: 1,
    createdAt: Timestamp.now(),
  });

  // Seed a few policy acks
  for (let a = 1; a <= 72; a++) {
    batch4.set(doc(db, "Firms", firmId, "notices", "notice_policy_1", "acks", `staff_${a.toString().padStart(3, "0")}`), {
      version: 2,
      at: Timestamp.now(),
    });
  }

  // 7. Audit Log entries
  const auditEntries = [
    { action: "staff_added", label: "Cynthia Vance", actor: "Sarah Connor", hoursAgo: 1 },
    { action: "code_reset", label: "Derek Morgan", actor: "Sarah Connor", hoursAgo: 4 },
    { action: "dept_head_assigned", label: "Global Operations", actor: "Sarah Connor", hoursAgo: 12 },
    { action: "notice_published", label: "Q4 Remote Work Security Policy", actor: "Sarah Connor", hoursAgo: 24 },
    { action: "staff_revoked", label: "staff_115", actor: "Sarah Connor", hoursAgo: 48 },
    { action: "dept_created", label: "Legal & Compliance", actor: "Sarah Connor", hoursAgo: 72 },
  ];

  for (let k = 0; k < auditEntries.length; k++) {
    const e = auditEntries[k];
    batch4.set(doc(db, "Firms", firmId, "auditLog", `audit_${k + 1}`), {
      actorId: adminUid,
      actorName: e.actor,
      action: e.action,
      targetType: "staff",
      targetId: `target_${k}`,
      targetLabel: e.label,
      createdAt: Timestamp.fromDate(new Date(now.getTime() - e.hoursAgo * 60 * 60 * 1000)),
    });
  }

  await batch4.commit();
  console.log("  ✓ Created Projects, Notice Index, Policy Acks, and Audit Log");

  console.log("\n==================================================================");
  console.log("✅ EMULATOR SEEDING COMPLETE!");
  console.log(`Firm: ${firmId} (Acme Global Dynamics)`);
  console.log(`Admin Sign-in: sarah@acme.com`);
  console.log("==================================================================\n");
}

seed().catch((err) => {
  console.error("Seeding failed:", err);
  process.exit(1);
});

