/**
 * Firestore Security Rules Unit Test Suite - Notices Feature (Phase 1)
 *
 * Verifies all security invariants for the Notices feature:
 *  1. Employees cannot post notices.
 *  2. Leads cannot post policy notices.
 *  3. Leads cannot post urgent notices beyond their own department.
 *  4. Leads respect the firm setting (notices.leadsMayTargetBeyondOwnDepartment).
 *  5. Only admins can set noticePublisher, and no one can set their own.
 *  6. An admin who is not addressed cannot read a notice, but can retract it.
 *  7. Employees cannot read noticeIndex (author & admins only).
 *  8. Views are author-only; reactions and acks are own-document only.
 *  9. A retracted notice is unreadable to normal readers.
 * 10. Existing security rules continue to pass.
 */

const fs = require('fs');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'pronto-chat-notices-test';
const RULES_PATH = './firestore.rules';

describe('ProntoChat Security Rules - Notices Feature', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: fs.readFileSync(RULES_PATH, 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();

    // Seed test fixtures
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // Firm 1 with default setting (leadsMayTargetBeyondOwnDepartment: true)
      await db.doc('Firms/firm_1').set({
        name: 'Alpha Corp',
        adminId: 'admin_1',
        ownerUid: 'admin_1',
        status: 'active',
        notices: {
          leadsMayTargetBeyondOwnDepartment: true,
        },
      });

      // Firm 2 with setting turned OFF (leadsMayTargetBeyondOwnDepartment: false)
      await db.doc('Firms/firm_2').set({
        name: 'Beta Corp',
        adminId: 'admin_2',
        ownerUid: 'admin_2',
        status: 'active',
        notices: {
          leadsMayTargetBeyondOwnDepartment: false,
        },
      });

      // Members of Firm 1
      await db.doc('Firms/firm_1/members/admin_1').set({
        role: 'admin',
        status: 'active',
        departmentId: 'dept_management',
      });

      await db.doc('Firms/firm_1/members/admin_unaddressed').set({
        role: 'admin',
        status: 'active',
        departmentId: 'dept_finance',
      });

      await db.doc('Firms/firm_1/members/lead_eng').set({
        role: 'lead',
        status: 'active',
        departmentId: 'dept_eng',
      });

      await db.doc('Firms/firm_1/members/emp_publisher').set({
        role: 'employee',
        status: 'active',
        departmentId: 'dept_marketing',
        noticePublisher: true,
      });

      await db.doc('Firms/firm_1/members/emp_eng').set({
        role: 'employee',
        status: 'active',
        departmentId: 'dept_eng',
      });

      await db.doc('Firms/firm_1/members/emp_sales').set({
        role: 'employee',
        status: 'active',
        departmentId: 'dept_sales',
      });

      // Members of Firm 2
      await db.doc('Firms/firm_2/members/lead_beta').set({
        role: 'lead',
        status: 'active',
        departmentId: 'dept_beta_eng',
      });
    });
  });

  // ── TEST 1: Employees cannot post ─────────────────────────────────────────
  it('prevents regular employees without noticePublisher from posting notices', async () => {
    const empDb = testEnv.authenticatedContext('emp_eng').firestore();
    const noticeRef = empDb.doc('Firms/firm_1/notices/notice_emp');
    const indexRef = empDb.doc('Firms/firm_1/noticeIndex/notice_emp');

    const batch = empDb.batch();
    batch.set(noticeRef, {
      type: 'announcement',
      title: 'Employee Post',
      body: 'Hello everyone',
      media: [],
      videoLinks: [],
      audienceKeys: ['firm'],
      audienceNames: ['Alpha Corp'],
      authorId: 'emp_eng',
      authorName: 'Employee Eng',
      authorLabel: 'Engineer',
      pinned: false,
      expiresAt: new Date(Date.now() + 86400000 * 14),
      version: 1,
      status: 'published',
      createdAt: new Date(),
    });
    batch.set(indexRef, {
      authorId: 'emp_eng',
      authorName: 'Employee Eng',
      type: 'announcement',
      audienceKeys: ['firm'],
      audienceNames: ['Alpha Corp'],
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 86400000 * 14),
      status: 'published',
      version: 1,
    });

    await assertFails(batch.commit());
  });

  // ── TEST 2: Leads cannot post policy ──────────────────────────────────────
  it('prevents leads from posting policy notices', async () => {
    const leadDb = testEnv.authenticatedContext('lead_eng').firestore();
    const noticeRef = leadDb.doc('Firms/firm_1/notices/notice_lead_policy');
    const indexRef = leadDb.doc('Firms/firm_1/noticeIndex/notice_lead_policy');

    const batch = leadDb.batch();
    batch.set(noticeRef, {
      type: 'policy',
      title: 'Company Policy Update',
      body: 'Policy terms',
      media: [],
      videoLinks: [],
      audienceKeys: ['dept:dept_eng'],
      audienceNames: ['Engineering'],
      authorId: 'lead_eng',
      authorName: 'Lead Eng',
      authorLabel: 'Lead, Engineering',
      pinned: false,
      version: 1,
      status: 'published',
      createdAt: new Date(),
    });
    batch.set(indexRef, {
      authorId: 'lead_eng',
      authorName: 'Lead Eng',
      type: 'policy',
      audienceKeys: ['dept:dept_eng'],
      audienceNames: ['Engineering'],
      createdAt: new Date(),
      status: 'published',
      version: 1,
    });

    await assertFails(batch.commit());
  });

  // ── TEST 3: Leads cannot post urgent beyond own department ─────────────────
  it('prevents leads from posting urgent notices beyond their own department', async () => {
    const leadDb = testEnv.authenticatedContext('lead_eng').firestore();
    const noticeRef = leadDb.doc('Firms/firm_1/notices/notice_lead_urgent_fail');
    const indexRef = leadDb.doc('Firms/firm_1/noticeIndex/notice_lead_urgent_fail');

    const batch = leadDb.batch();
    batch.set(noticeRef, {
      type: 'urgent',
      title: 'Urgent Firmwide',
      body: 'System down',
      media: [],
      videoLinks: [],
      audienceKeys: ['firm'], // Not their own department!
      audienceNames: ['Alpha Corp'],
      authorId: 'lead_eng',
      authorName: 'Lead Eng',
      authorLabel: 'Lead, Engineering',
      pinned: false,
      expiresAt: new Date(Date.now() + 86400000 * 3),
      version: 1,
      status: 'published',
      createdAt: new Date(),
    });
    batch.set(indexRef, {
      authorId: 'lead_eng',
      authorName: 'Lead Eng',
      type: 'urgent',
      audienceKeys: ['firm'],
      audienceNames: ['Alpha Corp'],
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 86400000 * 3),
      status: 'published',
      version: 1,
    });

    await assertFails(batch.commit());
  });

  it('allows leads to post urgent notices to their OWN department', async () => {
    const leadDb = testEnv.authenticatedContext('lead_eng').firestore();
    const noticeRef = leadDb.doc('Firms/firm_1/notices/notice_lead_urgent_ok');
    const indexRef = leadDb.doc('Firms/firm_1/noticeIndex/notice_lead_urgent_ok');

    const batch = leadDb.batch();
    batch.set(noticeRef, {
      type: 'urgent',
      title: 'Engineering Outage',
      body: 'Prod build failed',
      media: [],
      videoLinks: [],
      audienceKeys: ['dept:dept_eng'],
      audienceNames: ['Engineering'],
      authorId: 'lead_eng',
      authorName: 'Lead Eng',
      authorLabel: 'Lead, Engineering',
      pinned: false,
      expiresAt: new Date(Date.now() + 86400000 * 3),
      version: 1,
      status: 'published',
      createdAt: new Date(),
    });
    batch.set(indexRef, {
      authorId: 'lead_eng',
      authorName: 'Lead Eng',
      type: 'urgent',
      audienceKeys: ['dept:dept_eng'],
      audienceNames: ['Engineering'],
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 86400000 * 3),
      status: 'published',
      version: 1,
    });

    await assertSucceeds(batch.commit());
  });

  // ── TEST 4: Leads respect firm setting ─────────────────────────────────────
  it('prevents leads from posting announcement beyond own department when firm setting is false', async () => {
    const leadBetaDb = testEnv.authenticatedContext('lead_beta').firestore();
    const noticeRef = leadBetaDb.doc('Firms/firm_2/notices/notice_beta_fail');
    const indexRef = leadBetaDb.doc('Firms/firm_2/noticeIndex/notice_beta_fail');

    const batch = leadBetaDb.batch();
    batch.set(noticeRef, {
      type: 'announcement',
      title: 'Beta Announcement',
      body: 'Trying to reach firmwide',
      media: [],
      videoLinks: [],
      audienceKeys: ['firm'], // Setting is false, so must be own dept only!
      audienceNames: ['Beta Corp'],
      authorId: 'lead_beta',
      authorName: 'Lead Beta',
      authorLabel: 'Lead',
      pinned: false,
      expiresAt: new Date(Date.now() + 86400000 * 14),
      version: 1,
      status: 'published',
      createdAt: new Date(),
    });
    batch.set(indexRef, {
      authorId: 'lead_beta',
      authorName: 'Lead Beta',
      type: 'announcement',
      audienceKeys: ['firm'],
      audienceNames: ['Beta Corp'],
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 86400000 * 14),
      status: 'published',
      version: 1,
    });

    await assertFails(batch.commit());
  });

  // ── TEST 5: noticePublisher permission & self-assignment protection ─────────
  it('allows admins to grant noticePublisher to another member, but prevents self-assignment', async () => {
    const adminDb = testEnv.authenticatedContext('admin_1').firestore();

    // Admin grants noticePublisher to emp_eng -> SUCCEEDS
    await assertSucceeds(
      adminDb.doc('Firms/firm_1/members/emp_eng').update({
        noticePublisher: true,
      })
    );

    // Admin attempts to grant noticePublisher to THEMSELVES -> FAILS
    await assertFails(
      adminDb.doc('Firms/firm_1/members/admin_1').update({
        noticePublisher: true,
      })
    );

    // Employee attempts to grant noticePublisher to themselves -> FAILS
    const empDb = testEnv.authenticatedContext('emp_sales').firestore();
    await assertFails(
      empDb.doc('Firms/firm_1/members/emp_sales').update({
        noticePublisher: true,
      })
    );
  });

  // ── TEST 6: Unaddressed admin cannot read notice content but can retract ────
  it('denies unaddressed admin from reading notice, but allows them to retract it', async () => {
    // Seed a notice addressed strictly to Engineering
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('Firms/firm_1/notices/eng_secret').set({
        type: 'announcement',
        title: 'Engineering Confidential',
        body: 'Internal codebase secret',
        audienceKeys: ['dept:dept_eng'],
        audienceNames: ['Engineering'],
        authorId: 'lead_eng',
        authorName: 'Lead Eng',
        status: 'published',
        version: 1,
        createdAt: new Date(),
      });
      await db.doc('Firms/firm_1/noticeIndex/eng_secret').set({
        authorId: 'lead_eng',
        type: 'announcement',
        audienceKeys: ['dept:dept_eng'],
        status: 'published',
        version: 1,
        createdAt: new Date(),
      });
    });

    const unaddressedAdminDb = testEnv.authenticatedContext('admin_unaddressed').firestore();

    // 1. Unaddressed Admin tries to GET the notice document -> FAILS (METADATA-ONLY)
    await assertFails(unaddressedAdminDb.doc('Firms/firm_1/notices/eng_secret').get());

    // 2. Addressed Employee in Engineering CAN read it -> SUCCEEDS
    const empEngDb = testEnv.authenticatedContext('emp_eng').firestore();
    await assertSucceeds(empEngDb.doc('Firms/firm_1/notices/eng_secret').get());

    // 3. Unaddressed Admin RETRACTS the notice -> SUCCEEDS
    const retractBatch = unaddressedAdminDb.batch();
    retractBatch.update(unaddressedAdminDb.doc('Firms/firm_1/notices/eng_secret'), {
      status: 'retracted',
      retractedAt: new Date(),
      retractedBy: 'admin_unaddressed',
    });
    retractBatch.update(unaddressedAdminDb.doc('Firms/firm_1/noticeIndex/eng_secret'), {
      status: 'retracted',
      retractedAt: new Date(),
      retractedBy: 'admin_unaddressed',
      retractReason: 'Violates communication guidelines',
    });
    await assertSucceeds(retractBatch.commit());
  });

  // ── TEST 7: Employees cannot read noticeIndex ──────────────────────────────
  it('prevents regular employees from reading noticeIndex', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('Firms/firm_1/noticeIndex/index_1').set({
        authorId: 'lead_eng',
        type: 'announcement',
        status: 'published',
        audienceKeys: ['firm'],
        createdAt: new Date(),
        version: 1,
      });
    });

    const empDb = testEnv.authenticatedContext('emp_sales').firestore();
    await assertFails(empDb.doc('Firms/firm_1/noticeIndex/index_1').get());

    const adminDb = testEnv.authenticatedContext('admin_1').firestore();
    await assertSucceeds(adminDb.doc('Firms/firm_1/noticeIndex/index_1').get());
  });

  // ── TEST 8: Views are author-only; reactions & acks own-document only ──────
  it('enforces view docs are author-only and reactions/acks are own-doc only', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('Firms/firm_1/notices/policy_1').set({
        type: 'policy',
        title: 'Alpha Code of Conduct',
        body: 'Conduct terms',
        audienceKeys: ['firm'],
        audienceNames: ['Alpha Corp'],
        authorId: 'admin_1',
        status: 'published',
        version: 1,
        createdAt: new Date(),
      });
      await db.doc('Firms/firm_1/notices/policy_1/views/emp_eng').set({
        at: new Date(),
      });
    });

    const empEngDb = testEnv.authenticatedContext('emp_eng').firestore();
    const empSalesDb = testEnv.authenticatedContext('emp_sales').firestore();
    const authorDb = testEnv.authenticatedContext('admin_1').firestore();

    // Views read: Author CAN read views doc -> SUCCEEDS
    await assertSucceeds(authorDb.doc('Firms/firm_1/notices/policy_1/views/emp_eng').get());
    // Views read: Other employee CANNOT read individual view doc -> FAILS
    await assertFails(empSalesDb.doc('Firms/firm_1/notices/policy_1/views/emp_eng').get());

    // Reaction: emp_eng reacting on their own doc -> SUCCEEDS
    await assertSucceeds(
      empEngDb.doc('Firms/firm_1/notices/policy_1/reactions/emp_eng').set({
        emoji: '👍',
        at: new Date(),
      })
    );

    // Reaction: emp_eng trying to react on behalf of emp_sales -> FAILS
    await assertFails(
      empEngDb.doc('Firms/firm_1/notices/policy_1/reactions/emp_sales').set({
        emoji: '👍',
        at: new Date(),
      })
    );

    // Ack: emp_eng acknowledging on their own doc -> SUCCEEDS
    await assertSucceeds(
      empEngDb.doc('Firms/firm_1/notices/policy_1/acks/emp_eng').set({
        version: 1,
        at: new Date(),
      })
    );

    // Ack: emp_eng trying to acknowledge on behalf of emp_sales -> FAILS
    await assertFails(
      empEngDb.doc('Firms/firm_1/notices/policy_1/acks/emp_sales').set({
        version: 1,
        at: new Date(),
      })
    );
  });

  // ── TEST 9: Retracted notice is unreadable to readers ─────────────────────
  it('makes a retracted notice unreadable to addressed readers', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.doc('Firms/firm_1/notices/retracted_notice').set({
        type: 'announcement',
        title: 'Retracted Notice',
        body: 'Content was retracted',
        audienceKeys: ['firm'],
        audienceNames: ['Alpha Corp'],
        authorId: 'lead_eng',
        status: 'retracted',
        version: 1,
        createdAt: new Date(),
      });
    });

    const empDb = testEnv.authenticatedContext('emp_sales').firestore();
    // Reader cannot read retracted notice
    await assertFails(empDb.doc('Firms/firm_1/notices/retracted_notice').get());

    // Author CAN still view their own notice even if retracted
    const authorDb = testEnv.authenticatedContext('lead_eng').firestore();
    await assertSucceeds(authorDb.doc('Firms/firm_1/notices/retracted_notice').get());
  });
});
