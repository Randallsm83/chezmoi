---
name: Never modify app databases without true backup
description: Hard lesson from Warp incident — always copy-first before any DB changes, never chain destructive operations
type: feedback
---

NEVER modify application databases (SQLite or otherwise) without making a true backup FIRST — `cp` before any deletes or modifications. Do not `mv` and then edit the original location.

**Why:** During a Warp slowness fix, I moved the DB instead of copying, then ran DELETE statements before verifying the backup was clean. This cascaded into data loss and DB corruption. The user lost all Warp conversations, shell config, and indexed folders.

**How to apply:**
- Always `cp` (not `mv`) before touching any app database
- Verify the backup with `PRAGMA integrity_check` before making ANY changes to the original
- For app performance issues, suggest the user make the change themselves rather than running destructive commands directly — less risk of cascading mistakes
- When something goes wrong, stop and restore immediately instead of trying more fixes that compound the damage
- If the simplest fix is "delete the DB and let the app recreate it," say that upfront instead of attempting surgical edits
