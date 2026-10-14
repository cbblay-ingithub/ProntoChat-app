# Legacy Messages Migration Notes

> **Budget Constraint**: Firebase Spark Free Tier permits only **~20,000 writes per day**.
> Running a bulk backfill script across thousands of historical messages would immediately consume the entire project write quota and cause service disruption.

---

## 1. Zero Bulk-Write Policy

1. **No Migration Script**:
   We deliberately avoid batch-updating all existing messages in Firestore. Zero writes are spent on legacy documents upon deployment.
2. **Lazy Indexing on Edit**:
   When any existing message is edited by its author, `DBService.instance.editMessage(...)` automatically computes `searchTokens` via `SearchTokenUtil.generateTokens(newText)` and includes them in the single edit write.
3. **Lazy Indexing on New Messages**:
   All new messages created after this release automatically contain `searchTokens: [...]` at no additional write cost (it is part of the initial message creation document).

---

## 2. Multi-Stage In-Chat Search Strategy for Legacy Documents

To ensure users can still find historical messages that lack `searchTokens`:

| Stage | Data Source | Token Dependency | How Legacy Messages are Found | Write Cost | Read Cost |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Stage 1: Device Memory Cache** | Up to 100 loaded messages in RAM | **None** | Exact case-insensitive substring matching against `m.text` and `m.content`. Finds all loaded messages regardless of whether they have `searchTokens`. | 0 | 0 |
| **Stage 2: Server Indexed Query** | Firestore `where('searchTokens', arrayContains: query)` | Requires `searchTokens` | Queries indexed messages (new and edited). Up to 30 matches retrieved. | 0 | 1 read per matched doc |
| **Stage 3: History Pageback** | Older history batches (up to 300 docs) | **None** | Fetches historical documents via date cursor (`startAfterDocument`), applying in-memory substring search on the client. Caps at 300 docs to safeguard the daily 50,000 read quota. | 0 | 30 reads per batch (max 300) |

---

## 3. Legacy Direct Messages vs Channel Messages

- **Direct Messages**:
  Stored at `Conversations/{convId}/Messages/{msgId}`. New direct messages include `searchTokens`. Older direct messages are found via Stage 1 cache and Stage 3 cursor pageback.
- **Company & Department Channels**:
  Stored at `Firms/{firmId}/conversations/{convId}/messages/{msgId}`. Older channel messages work seamlessly across Stage 1 and Stage 3.

---

## 4. Deletion Clean-up

When a message is soft-deleted (`DBService.instance.deleteMessage`):
- `searchTokens` is updated to an empty list `[]`.
- This immediately removes the message from all future Stage 2 server index search results without requiring a hard delete.
