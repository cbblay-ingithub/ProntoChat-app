/**
 * Firestore Security Rules Unit Test Suite
 * 
 * Verifies security invariants for ProntoChat:
 *  - Part A: Search tokens & message access isolation
 *  - Part B: Mentions inbox access isolation
 *  - Part C: Poll creation permissions, active member voting (even in read-only),
 *            optionIds validation, closed poll protection, and poll closing permissions.
 *
 * Designed for use with `@firebase/rules-unit-testing` and the Firebase Local Emulator Suite.
 */

const fs = require('fs');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'pronto-chat-security-test';
const RULES_PATH = './firestore.rules';

describe('ProntoChat Security Rules - Search, Mentions, Polls', () => {
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

    // Seed test environment with firm and membership fixtures
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();

      // Firm 1
      await db.doc('Firms/firm_1').set({
        name: 'Alpha Corp',
        adminId: 'admin_1',
      });

      // Members of Firm 1
      await db.doc('Firms/firm_1/members/admin_1').set({
        name: 'Admin User',
        role: 'admin',
        status: 'active',
      });

      await db.doc('Firms/firm_1/members/lead_1').set({
        name: 'Lead User',
        role: 'lead',
        departmentId: 'dept_eng',
        status: 'active',
      });

      await db.doc('Firms/firm_1/members/emp_1').set({
        name: 'Employee One',
        role: 'employee',
        departmentId: 'dept_eng',
        status: 'active',
      });

      await db.doc('Firms/firm_1/members/emp_outsider').set({
        name: 'Employee Outsider',
        role: 'employee',
        departmentId: 'dept_sales',
        status: 'active',
      });

      // Conversations
      // #all-staff
      await db.doc('Firms/firm_1/conversations/all_staff').set({
        type: 'allStaff',
        name: '#all-staff',
      });

      // #dept_eng
      await db.doc('Firms/firm_1/conversations/dept_eng').set({
        type: 'department',
        departmentId: 'dept_eng',
        name: '#engineering',
      });

      // #proj_alpha (emp_1 and lead_1 are participants)
      await db.doc('Firms/firm_1/conversations/proj_alpha').set({
        type: 'project',
        name: 'Project Alpha',
        participantIds: ['emp_1', 'lead_1'],
      });

      // Seed an existing open poll message in #all-staff
      await db.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_1').set({
        type: 'poll',
        senderId: 'admin_1',
        senderName: 'Admin User',
        content: 'Company outing preference',
        searchTokens: ['company', 'outing', 'preference', 'lake', 'park'],
        timestamp: new Date(),
        poll: {
          pollId: 'poll_msg_1',
          question: 'Where should we hold the company outing?',
          options: [
            { optionId: 'opt_lake', text: 'Lake Resort' },
            { optionId: 'opt_park', text: 'Theme Park' },
          ],
          createdBy: 'admin_1',
          createdByName: 'Admin User',
          createdAt: new Date(),
          allowMultiple: false,
          closedAt: null,
        },
      });

      // Seed an existing closed poll message
      await db.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_closed').set({
        type: 'poll',
        senderId: 'admin_1',
        senderName: 'Admin User',
        content: 'Old poll',
        searchTokens: ['old', 'poll'],
        timestamp: new Date(),
        poll: {
          pollId: 'poll_msg_closed',
          question: 'Old Question',
          options: [{ optionId: 'opt_1', text: '1' }],
          createdBy: 'admin_1',
          createdByName: 'Admin User',
          createdAt: new Date(),
          allowMultiple: false,
          closedAt: new Date(), // ALREADY CLOSED
        },
      });
    });
  });

  describe('Part A: Search & Message Access Security', () => {
    it('allows conversation members to read messages matching search tokens', async () => {
      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const msgRef = empDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_1');
      await assertSucceeds(msgRef.get());
    });

    it('denies outsiders from reading messages in private project conversations', async () => {
      // emp_outsider is not in proj_alpha
      const outsiderDb = testEnv.authenticatedContext('emp_outsider').firestore();
      const msgRef = outsiderDb.doc('Firms/firm_1/conversations/proj_alpha/messages/msg_secret');
      await assertFails(msgRef.get());
    });

    it('denies non-participating admins from reading project conversations they are not in', async () => {
      // admin_1 is NOT in participantIds of proj_alpha
      const adminDb = testEnv.authenticatedContext('admin_1').firestore();
      const msgRef = adminDb.doc('Firms/firm_1/conversations/proj_alpha/messages/msg_secret');
      await assertFails(msgRef.get());
    });
  });

  describe('Part B: Mentions Inbox Isolation', () => {
    it('allows users to read and mark their own mention inbox items', async () => {
      // Seed mention item for emp_1
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().doc('Firms/firm_1/mentions/emp_1/items/msg_123').set({
          messageId: 'msg_123',
          firmId: 'firm_1',
          senderId: 'lead_1',
          read: false,
        });
      });

      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const itemRef = empDb.doc('Firms/firm_1/mentions/emp_1/items/msg_123');

      // Read own item
      await assertSucceeds(itemRef.get());

      // Update own item (mark as read)
      await assertSucceeds(itemRef.update({ read: true }));
    });

    it('denies other users from reading another person’s mention inbox', async () => {
      const outsiderDb = testEnv.authenticatedContext('emp_outsider').firestore();
      const itemRef = outsiderDb.doc('Firms/firm_1/mentions/emp_1/items/msg_123');
      await assertFails(itemRef.get());
    });

    it('allows message senders in firm to write a mention item during fan-out', async () => {
      const leadDb = testEnv.authenticatedContext('lead_1').firestore();
      const itemRef = leadDb.doc('Firms/firm_1/mentions/emp_1/items/msg_new_mention');
      await assertSucceeds(
        itemRef.set({
          messageId: 'msg_new_mention',
          firmId: 'firm_1',
          conversationId: 'dept_eng',
          senderId: 'lead_1',
          read: false,
          createdAt: new Date(),
        })
      );
    });
  });

  describe('Part C: Poll Creation & Voting Permissions', () => {
    it('allows Admin or Lead to create a poll in #all-staff', async () => {
      const leadDb = testEnv.authenticatedContext('lead_1').firestore();
      const newPollRef = leadDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_lead_1');

      await assertSucceeds(
        newPollRef.set({
          type: 'poll',
          senderId: 'lead_1',
          senderName: 'Lead User',
          content: 'Team Lunch Options',
          timestamp: new Date(),
          searchTokens: ['team', 'lunch', 'options'],
          poll: {
            pollId: 'poll_lead_1',
            question: 'Team Lunch Options',
            options: [
              { optionId: 'opt_1', text: 'Tacos' },
              { optionId: 'opt_2', text: 'Burgers' },
            ],
            createdBy: 'lead_1',
            createdByName: 'Lead User',
            createdAt: new Date(),
            allowMultiple: false,
          },
        })
      );
    });

    it('denies regular employee from creating a poll in #all-staff announcements', async () => {
      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const newPollRef = empDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_emp_denied');

      await assertFails(
        newPollRef.set({
          type: 'poll',
          senderId: 'emp_1',
          senderName: 'Employee One',
          content: 'Should not be allowed',
          timestamp: new Date(),
          searchTokens: ['should', 'not'],
          poll: {
            pollId: 'poll_emp_denied',
            question: 'Denied',
            options: [{ optionId: '1', text: 'A' }, { optionId: '2', text: 'B' }],
            createdBy: 'emp_1',
          },
        })
      );
    });

    it('allows regular employee to VOTE in #all-staff even though they cannot post messages', async () => {
      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const voteRef = empDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_1/votes/emp_1');

      await assertSucceeds(
        voteRef.set({
          voterUid: 'emp_1',
          voterName: 'Employee One',
          optionIds: ['opt_lake'],
          votedAt: new Date(),
        })
      );
    });

    it('enforces single-choice when poll does not allowMultiple', async () => {
      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const voteRef = empDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_1/votes/emp_1');

      // Attempting to select 2 options on a single-choice poll fails
      await assertFails(
        voteRef.set({
          voterUid: 'emp_1',
          voterName: 'Employee One',
          optionIds: ['opt_lake', 'opt_park'],
          votedAt: new Date(),
        })
      );
    });

    it('denies voting for options that do not exist in the poll (subset validation)', async () => {
      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const voteRef = empDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_1/votes/emp_1');

      // 'opt_fake' is not in options
      await assertFails(
        voteRef.set({
          voterUid: 'emp_1',
          voterName: 'Employee One',
          optionIds: ['opt_fake'],
          votedAt: new Date(),
        })
      );
    });

    it('denies voting once poll is closed', async () => {
      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const voteRef = empDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_closed/votes/emp_1');

      await assertFails(
        voteRef.set({
          voterUid: 'emp_1',
          voterName: 'Employee One',
          optionIds: ['opt_1'],
          votedAt: new Date(),
        })
      );
    });

    it('allows creator or firm admin to close the poll', async () => {
      const adminDb = testEnv.authenticatedContext('admin_1').firestore();
      const pollRef = adminDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_1');

      await assertSucceeds(
        pollRef.update({
          'poll.closedAt': new Date(),
        })
      );
    });

    it('denies other non-admin employees from closing the poll', async () => {
      const empDb = testEnv.authenticatedContext('emp_1').firestore();
      const pollRef = empDb.doc('Firms/firm_1/conversations/all_staff/messages/poll_msg_1');

      await assertFails(
        pollRef.update({
          'poll.closedAt': new Date(),
        })
      );
    });
  });
});
