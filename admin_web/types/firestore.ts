/**
 * Firestore data model types mirroring ProntoChat schema
 */

export interface MediaRef {
  provider: 'cloudinary';
  key: string;
  kind: 'image';
  w?: number;
  h?: number;
  bytes?: number;
  format?: string;
  uploadedAt?: any;
}

export interface Firm {
  firmId: string;
  name: string;
  primaryColor: string;
  secondaryColor?: string;
  ownerUid: string;
  adminId: string;
  plan: 'trial' | 'active' | 'pro';
  status: 'active' | 'suspended';
  seatLimit: number;
  seatCount: number;
  termsAcceptedAt: any;
  createdAt: any;
  logoUrl?: string;
  logo?: MediaRef;
  inviteToken?: string;
  showLastSeen: boolean;
  showReadReceipts: boolean;
  welcomeText?: string;
}

export interface Membership {
  uid: string;
  firmId: string;
  name?: string;
  email?: string;
  role: 'admin' | 'super_admin' | 'lead' | 'employee';
  status: 'active' | 'pending' | 'revoked';
  departmentId?: string;
  createdAt?: any;
  joinedAt?: any;
  approvedAt?: any;
}

export interface FirmMember {
  name: string;
  role: 'admin' | 'super_admin' | 'lead' | 'employee';
  status: 'active' | 'pending' | 'revoked';
  departmentId?: string | null;
  joinedAt?: any;
  createdAt?: any;
  revokedAt?: any;
  avatarUrl?: string;
}

export interface PreApprovedStaff {
  id: string;
  email: string;
  name: string;
  code?: string;
  codeExpiresAt?: any;
  codeUpdatedAt?: any;
  status: 'invited' | 'joined';
  role: 'admin' | 'lead' | 'employee';
  departmentId?: string;
  invitedAt: any;
  joinedAt?: any;
  uid?: string;
}

export interface Department {
  id: string;
  name: string;
  headUid?: string | null;
  status: 'active' | 'archived';
  createdBy?: string;
  conversationId?: string;
  createdAt?: any;
}

export interface ProjectGroup {
  id: string;
  name: string;
  ownerUid: string;
  participantIds: string[];
  status: 'active' | 'archived';
  conversationId?: string;
  createdAt?: any;
}

export interface NoticeIndex {
  id: string;
  authorId: string;
  authorName: string;
  type: 'announcement' | 'urgent' | 'policy';
  audienceKeys: string[];
  audienceNames?: string[];
  status: 'published' | 'retracted';
  version: number;
  createdAt: any;
  expiresAt?: any;
  retractedAt?: any;
  retractedBy?: string;
  retractReason?: string;
}

export interface NoticeAck {
  version: number;
  at: any;
}

export interface AuditEntry {
  id: string;
  actorId: string;
  actorName: string;
  action: string;
  targetType: string;
  targetId: string;
  targetLabel: string;
  createdAt: any;
}

export interface UserPresence {
  uid: string;
  lastSeenAt: any;
}

