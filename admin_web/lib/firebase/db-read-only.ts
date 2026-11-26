/**
 * Enforced Read-Only Firestore Data Access Layer
 *
 * MANDATORY REQUIREMENT:
 * This prototype performs NO Firestore writes of any kind.
 * Only getDoc, getDocs, and getCountFromServer queries are allowed.
 * No write operations (addDoc, setDoc, updateDoc, deleteDoc, writeBatch, runTransaction) exist here.
 */

import {
  doc,
  collection,
  query,
  getDoc,
  getDocs,
  getCountFromServer,
  type DocumentReference,
  type DocumentSnapshot,
  type Query,
  type QuerySnapshot,
  type AggregateQuerySnapshot,
  type DocumentData,
} from "firebase/firestore";
import { db } from "./client";

/**
 * Fetch a single document by reference (read-only)
 */
export async function readOnlyGetDoc<T = DocumentData>(
  docRef: DocumentReference<T>
): Promise<DocumentSnapshot<T>> {
  return getDoc(docRef);
}

/**
 * Fetch query documents (read-only)
 */
export async function readOnlyGetDocs<T = DocumentData>(
  q: Query<T>
): Promise<QuerySnapshot<T>> {
  return getDocs(q);
}

/**
 * Fetch server-side count aggregate (read-only, costs 1 read per up to 1,000 index entries)
 */
export async function readOnlyCount(
  q: Query
): Promise<number> {
  const snapshot = await getCountFromServer(q);
  return snapshot.data().count;
}

/**
 * Helper to build typed document references
 */
export function getDocRef<T = DocumentData>(path: string, ...pathSegments: string[]): DocumentReference<T> {
  return doc(db, path, ...pathSegments) as DocumentReference<T>;
}

/**
 * Helper to build typed collection references
 */
export function getCollectionRef<T = DocumentData>(path: string, ...pathSegments: string[]) {
  return collection(db, path, ...pathSegments);
}

// Banned write operations: will throw compile-time / runtime errors if attempted
export function bannedWriteOperation(): never {
  throw new Error("VIOLATION: ProntoChat Admin Prototype is strictly READ-ONLY. No Firestore writes permitted.");
}

