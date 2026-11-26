# SCHEMA.md — ProntoChat Firestore Schema Documentation

This document defines the TypeScript models mirroring Firestore documents across ProntoChat, designed to be shared and kept in parity between the Flutter client and the Next.js Admin Console.

---

## 1. Top-Level Collections

### `Firms/{firmId}`
Root multi-tenant entity representing an enterprise or organization.

```typescript
export interface Firm {
  firmId: string;
  name: string;
  primaryColor: string; // e.g., "#295CB4" or "#10B981"
  secondaryColor?: string;
  ownerUid: string;
  adminId: string; // Backward-compatible alias for ownerUid
  plan: 'trial' | 'active' | 'pro'; // Default 'trial'
  status: 'active' | 'suspended';
  seatLimit: number; // Trial tier default is 5
  seatCount: number; // Stored counter of active members + invited staff
  termsAcceptedAt: string | Timestamp;
  createdAt: string | Timestamp;
  logoUrl?: string;
  logo?: MediaRef;
  inviteToken?: string;
  showLastSeen: boolean; // Controls whether 7-day presence engagement can be viewed
  showReadReceipts: boolean;
  notices?: {
    leadsMayTargetBeyondOwnDepartment?: boolean;
  };
  welcomeText?: string;
}
```

### `Memberships/{uid}`
Root lookup document mapping an authenticated user UID to their firm and access status.

```typescript
export interface Membership {
  uid: string;
  firmId: string;
  name?: string;
  email?: string;
  role: 'admin' | 'super_admin' | 'lead' | 'employee';
  status: 'active' | 'pending' | 'revoked';
  departmentId?: string;
  createdAt: string | Timestamp;
  joinedAt?: string | Timestamp;
  approvedAt?: string | Timestamp;
}
```

### `Users/{uid}`
User identity profile.

```typescript
export interface UserProfile {
  name: string;
  nameLower: string;
  email: string;
  role: 'admin' | 'super_admin' | 'lead' | 'employee';
  firmIds: string[];
  ownedFirmId?: string;
  lastSeen?: Timestamp;
  createdAt?: Timestamp;
  avatarUrl?: string;
  jobTitle?: string;
}
```

---

## 2. Firm Subcollections

### `Firms/{firmId}/members/{uid}`
Firm-specific member directory entry.

```typescript
export interface FirmMember {
  name: string;
  role: 'admin' | 'super_admin' | 'lead' | 'employee';
  status: 'active' | 'pending' | 'revoked';
  departmentId?: string | null;
  joinedAt: Timestamp;
  createdAt: Timestamp;
  revokedAt?: Timestamp;
  avatarUrl?: string;
}
```

### `Firms/{firmId}/PreApprovedStaff/{staffDocId}`
One-time staff invitation codes and pending employee invites.

```typescript
export interface PreApprovedStaff {
  email: string;
  name: string;
  code?: string; // Deleted atomically upon employee join
  codeExpiresAt?: Timestamp; // 5-minute rolling expiration; deleted upon join
  codeUpdatedAt?: Timestamp;
  status: 'invited' | 'joined';
  role: 'admin' | 'lead' | 'employee';
  departmentId?: string;
  invitedAt: Timestamp;
  joinedAt?: Timestamp; // Recorded when status transitions to 'joined'
  uid?: string; // Set when claimed
}
```

### `Firms/{firmId}/departments/{deptId}`
Organizational departments.

```typescript
export interface Department {
  name: string;
  headUid?: string | null; // UID of the department lead
  status: 'active' | 'archived';
  createdBy: string;
  conversationId: string;
  createdAt: Timestamp;
}
```

### `Firms/{firmId}/projects/{projectId}`
Cross-functional project groups.

```typescript
export interface ProjectGroup {
  name: string;
  ownerUid: string;
  participantIds: string[];
  status: 'active' | 'archived';
  conversationId: string;
  createdAt: Timestamp;
}
```

### `Firms/{firmId}/noticeIndex/{noticeId}`
Metadata-only notice index for administrative oversight. Strictly excludes confidential body text, titles, and media links to preserve employee privacy.

```typescript
export interface NoticeIndex {
  authorId: string;
  authorName: string;
  type: 'announcement' | 'urgent' | 'policy';
  audienceKeys: string[]; // e.g., ["firm"], ["dept:dept123"]
  audienceNames: string[];
  status: 'published' | 'retracted';
  version: number;
  createdAt: Timestamp;
  expiresAt?: Timestamp;
  retractedAt?: Timestamp;
  retractedBy?: string;
  retractReason?: string;
}
```

### `Firms/{firmId}/notices/{noticeId}/acks/{uid}`
Policy acknowledgement records for compliance reporting.

```typescript
export interface NoticeAck {
  version: number;
  at: Timestamp;
}
```

### `Firms/{firmId}/auditLog/{auditId}`
Append-only log of admin actions.

```typescript
export interface AuditEntry {
  actorId: string;
  actorName: string;
  action:
    | 'staff_added'
    | 'staff_revoked'
    | 'staff_reinstated'
    | 'code_reset'
    | 'dept_created'
    | 'dept_archived'
    | 'dept_head_assigned'
    | 'notice_published'
    | 'notice_retracted'
    | 'branding_updated';
  targetType: 'staff' | 'department' | 'project' | 'notice' | 'firm';
  targetId: string;
  targetLabel: string;
  createdAt: Timestamp;
}
```

### `Firms/{firmId}/presence/{uid}`
Activity presence indicator (throttled write at most once every 5 minutes).

```typescript
export interface UserPresence {
  uid: string;
  lastSeenAt: Timestamp;
}
```

---

## 3. Media Reference Shape (Cloudinary)

Stored under `Firm.logo`:

```typescript
export interface MediaRef {
  provider: 'cloudinary';
  key: string; // Cloudinary public_id, e.g. "prontochat/logos/abc123"
  kind: 'image';
  w?: number;
  h?: number;
  bytes?: number;
  format?: string;
  uploadedAt?: Timestamp;
}
```
Delivery URL:
`https://res.cloudinary.com/${cloudName}/image/upload/t_${variant}/${key}`
where `variant` is `logo_sm` (128px) or `logo_lg` (512px).

