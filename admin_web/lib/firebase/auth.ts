/**
 * Authentication and Membership / Role Resolution
 * Matches Flutter's auth and lookup logic identically.
 */

import {
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  onAuthStateChanged,
  type User,
} from "firebase/auth";
import { query, where, limit, Timestamp } from "firebase/firestore";
import { auth } from "./client";
import {
  readOnlyGetDoc,
  readOnlyGetDocs,
  getDocRef,
  getCollectionRef,
} from "./db-read-only";
import { Firm, Membership } from "@/types/firestore";

export interface ResolvedAdminSession {
  user: User;
  membership: Membership | null;
  firm: Firm | null;
  isAdmin: boolean;
  isRevoked: boolean;
  isPending: boolean;
  isFirmSuspended: boolean;
}

/**
 * Sign in with email and password
 */
export async function signInAdmin(email: string, pass: string): Promise<User> {
  const cred = await signInWithEmailAndPassword(auth, email.trim(), pass);
  return cred.user;
}

/**
 * Sign out (clears shared session)
 */
export async function signOutAdmin(): Promise<void> {
  await firebaseSignOut(auth);
}

/**
 * Resolves a signed-in user's firm, membership and admin status.
 * Replicates lib/providers/firm/providers.dart (lines 73-160).
 */
export async function resolveAdminSession(user: User): Promise<ResolvedAdminSession> {
  let membership: Membership | null = null;
  let firmId: string | null = null;
  let role: string = "employee";
  let status: string = "active";

  try {
    // 1. Primary lookup: Memberships/{uid}
    const membershipSnap = await readOnlyGetDoc<Membership>(
      getDocRef<Membership>("Memberships", user.uid)
    );

    if (membershipSnap.exists()) {
      membership = { ...membershipSnap.data(), uid: user.uid };
      firmId = membership.firmId;
      role = (membership.role || "employee").toLowerCase();
      status = (membership.status || "active").toLowerCase();
    } else {
      // 2. Fallback: Users/{uid}
      const userSnap = await readOnlyGetDoc(getDocRef("Users", user.uid));
      if (userSnap.exists()) {
        const uData = userSnap.data() || {};
        const firmIds = uData.firmIds as string[] | undefined;
        const ownedFirmId = uData.ownedFirmId as string | undefined;
        firmId = firmIds && firmIds.length > 0 ? firmIds[0] : ownedFirmId || null;

        if (firmId) {
          const memberSnap = await readOnlyGetDoc(
            getDocRef("Firms", firmId, "members", user.uid)
          );
          if (memberSnap.exists()) {
            const mData = memberSnap.data() || {};
            role = (mData.role || "employee").toLowerCase();
            status = (mData.status || "active").toLowerCase();
            membership = {
              uid: user.uid,
              firmId,
              role: role as any,
              status: status as any,
              departmentId: mData.departmentId,
              joinedAt: mData.joinedAt,
              createdAt: mData.createdAt,
            };
          }
        }

        // 3. Fallback: Firms where adminId == uid
        if (!firmId) {
          const firmQuery = query(
            getCollectionRef("Firms"),
            where("adminId", "==", user.uid),
            limit(1)
          );
          const firmQuerySnap = await readOnlyGetDocs(firmQuery);
          if (!firmQuerySnap.empty) {
            firmId = firmQuerySnap.docs[0].id;
            role = "admin";
            status = "active";
            membership = {
              uid: user.uid,
              firmId,
              role: "admin",
              status: "active",
            };
          }
        }
      }
    }
  } catch (err) {
    console.error("[resolveAdminSession] Error resolving membership:", err);
  }

  // Fetch Firm record
  let firm: Firm | null = null;
  let isFirmSuspended = false;

  if (firmId) {
    try {
      const firmSnap = await readOnlyGetDoc<Firm>(getDocRef<Firm>("Firms", firmId));
      if (firmSnap.exists()) {
        firm = { ...firmSnap.data(), firmId: firmSnap.id };
        isFirmSuspended = firm.status === "suspended";
      }
    } catch (err) {
      console.error("[resolveAdminSession] Error fetching firm:", err);
    }
  }

  const isAdmin = role === "admin" || role === "super_admin";
  const isRevoked = status === "revoked";
  const isPending = status === "pending";

  return {
    user,
    membership,
    firm,
    isAdmin,
    isRevoked,
    isPending,
    isFirmSuspended,
  };
}

/**
 * Auth state listener
 */
export function subscribeToAuthState(callback: (user: User | null) => void) {
  return onAuthStateChanged(auth, callback);
}

