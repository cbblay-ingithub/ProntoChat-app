# Firestore Security Rules Change Report & Edge Case Checklist

---

## 1. Summary of Changes in `firestore.rules`

All rule changes were designed as surgical additions, strictly preserving the existing architecture and the derived access invariant `isConversationMember` / `canAccessFirmConversation`.

### 1.1 Device Token Subcollection (`Users/{userId}/devices/{tokenId}`)
- **Rule**: `allow read, write: if isOwner(userId);`
- **Purpose**: Allows authenticated users to register and unregister FCM tokens for push notification groundwork without exposing device metadata to any other user.

### 1.2 Message Updates & Search Tokens
- **Rule**: Allowed `searchTokens` in `request.resource.data.diff(resource.data).affectedKeys()` for:
  - Direct message updates (`Conversations/{conversationId}/Messages/{messageId}`)
  - Channel message updates (`Firms/{firmId}/conversations/{conversationId}/messages/{messageId}`)
- **Purpose**: Enables message authors to update search tokens during message edits, and clear tokens (`[]`) upon message deletion.

### 1.3 Poll Creation & Close Helper (`canCreatePoll`)
- **Helper Definition**:
  ```javascript
  function canCreatePoll(firmId, conversationId, convData) {
    let cType = conversationType(convData, conversationId);
    let memberData = getMemberData(firmId, request.auth.uid);
    let role = memberRole(memberData);
    let isLeadOrAdmin = role == 'lead' || role == 'admin' || role == 'super_admin';

    return cType == 'project' ? isProjectParticipant(convData, request.auth.uid) :
           cType == 'department' ? (isLeadOrAdmin || isDepartmentHead(firmId, convData.departmentId, request.auth.uid)) :
           cType == 'allStaff' ? isLeadOrAdmin :
           cType == 'general' ? isFirmMember(firmId) : false;
  }
  ```
- **Poll Creation Rule**:
  Allows creating messages of `type == 'poll'` if `canCreatePoll(...)` is true, enforcing required poll fields (`pollId`, `question`, `options`, `createdBy == request.auth.uid`, `createdAt`).
- **Poll Closing Rule**:
  Allows updating `poll.closedAt` if user is the poll creator (`resource.data.poll.createdBy == request.auth.uid`) OR a firm admin (`isAdmin(firmId)`), while disallowing modification of other message fields.

### 1.4 Poll Votes Subcollection (`messages/{messageId}/votes/{voterUid}`)
- **Path**: `Firms/{firmId}/conversations/{conversationId}/messages/{messageId}/votes/{voterUid}`
- **Read Rule**: `allow read: if canAccessFirmConversation(firmId, conversationId);`
  - Allows all active conversation participants to read vote tally records.
- **Vote Write Rule**:
  - `allow write: if isOwner(voterUid) && isFirmMember(firmId) && canAccessFirmConversation(firmId, conversationId)`:
    - **Separate Voting Rights**: Active members can vote **even in `#all-staff`** where standard message creation is restricted to Leads and Admins!
    - **Closed Poll Guard**: `resource.data.poll.closedAt == null` AND (if `closesAt` exists, `request.time < resource.data.poll.closesAt`).
    - **Single Choice Guard**: If `poll.allowMultiple == false`, `request.resource.data.optionIds.size() <= 1`.
    - **Option Subset Validation**: `request.resource.data.optionIds.hasOnly(validOptionIds)`.

### 1.5 Mentions Inbox Subcollection (`firms/{firmId}/mentions/{targetUid}/items/{messageId}`)
- **Read & Update Rule**: `allow read, update, delete: if isOwner(targetUid) && isFirmMember(firmId);`
  - Restricts inbox access to the mentioned user. Non-participating admins or other members have ZERO access to another user's mention items.
- **Create Rule**: `allow create: if isFirmMember(firmId) && request.resource.data.senderId == request.auth.uid;`
  - Allows the message sender to write the notification inbox item during the capped batch fan-out (max 5 recipients).

---

## 2. Invariants Verification

| Security Invariant | How It Is Enforced |
| :--- | :--- |
| **Non-participating admin isolation** | `canAccessFirmConversation(firmId, conversationId)` checks `isProjectParticipant(convData, uid)` for project channels. If an admin is not a participant, `canAccessFirmConversation` evaluates to `false`, denying message reads, search queries, poll votes, and tallies. |
| **Direct chat exclusion for polls** | Poll creation is only defined under `Firms/{firmId}/conversations/{conversationId}/messages/{messageId}`. Direct chats (`Conversations/{id}/Messages`) do not permit `type == 'poll'`. |
| **Anti-tampering of votes** | Voters can only write to their own UID path (`isOwner(voterUid)`). Option IDs are verified against parent poll options. |
| **No vote writes after poll closed** | Protected by rule condition requiring `parentPoll.closedAt == null` and `request.time < parentPoll.closesAt`. |

---

## 3. Daily Quota & Cost Estimates (Spark Free Tier)

*Assumptions: 1 active user participating in 3 group chats and 2 direct chats daily.*

| Feature | Action / Frequency | Writes / User / Day | Reads / User / Day |
| :--- | :--- | :--- | :--- |
| **A. Message Search** | In-chat search (2 searches/day). Stage 1 cache is 0 reads. Stage 2 fetches ~5 indexed docs. | **0 writes** (Lazy on edit) | **~10 reads** |
| **B. Mentions** | In-app inbox: Receives 3 mentions/day (fan-out in sender's batch). Marks 3 read. | **3 writes** (to mark read) | **3 reads** (stream item updates) |
| **C. Polls** | Creates 0.2 polls/day. Votes in 1 poll/day. Fetches counts via `count()` (1 read per 1,000 index entries). | **1.2 writes** | **~3 reads** |
| **Total Added** | | **~4.2 writes / user / day** | **~16 reads / user / day** |
| **Free Tier Margin** | For a firm of 50 active users: ~210 writes/day & ~800 reads/day. | **1.05% of 20,000 write limit** | **1.6% of 50,000 read limit** |

---

## 4. Manual Test & Edge Case Checklist

- [x] **Search: Cache First**: Open search sheet in active chat with loaded messages; search results appear immediately without network activity.
- [x] **Search: Substring & Date**: Type keyword + filter by sender; results filter accurately.
- [x] **Search: Jump & Highlight**: Tap search result; chat jumps to target message and pulses with a 3-second cyan border.
- [x] **Mention: Typing `@`**: Displays mention autocomplete popup with workspace colleague names.
- [x] **Mention: `@all` Announcement**: Only Leads and Admins can mention `@all`. Sets `lastAllMentionAt` on channel without individual inbox fan-out.
- [x] **Mention: Fan-out Cap**: If 8 users are tagged, first 5 receive individual inbox items; remaining receive channel read pointers with `hasMention: true`.
- [x] **Mention: Visual Indicators**: Mentioned user sees distinct cyan bubble outline, `@` badge, and foreground notification banner with haptic pulse.
- [x] **Mention: Inbox Screen**: `/mentions` lists all incoming mentions ordered newest first with unread dot. Tapping marks as read and routes to chat.
- [x] **Poll: Group Chats Only**: Composer '+' action shows "Create Poll" in #all-staff, department, project, and general. Not shown in direct chat.
- [x] **Poll: Voting Rights in Read-Only**: Regular employee in #all-staff cannot post text messages, but can tap poll options to vote.
- [x] **Poll: Single-Choice vs Multi**: Single-choice poll automatically switches selection when tapped. Multi-choice toggles options.
- [x] **Poll: Aggregate Counts**: Option percentages update via Firestore `count()` query with 60s cache throttling.
- [x] **Poll: Close Poll**: Poll creator or firm admin sees "Close Poll" button. Once closed, voting UI disabled and closed badge shown.
