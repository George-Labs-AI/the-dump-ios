# Backend Task: Build `POST /api/file_status` Endpoint

## Why We're Doing This

On the iOS app's main capture screen, we used to show a list of "uploads this session" — once a file uploaded successfully, it just said "Uploaded" and sat there. That's not useful because the user doesn't care that the file reached cloud storage — they care that their note was **processed and organized by the AI**.

We've updated the iOS client to show a "Processing" section instead. The flow is now:

1. User captures something (photo, voice, file, text)
2. Upload completes → iOS stores the `uuid` from the existing `POST /api/mobile/upload_file` response
3. iOS shows "Processing..." with a pulsing animation
4. **iOS polls a new endpoint every 5 seconds** asking "what happened to these file UUIDs?"
5. When the backend says "completed", iOS shows "Organized → [Category Name]" with a tap target that navigates to the full organized note (using `organized_note_id`)
6. After 6 seconds the item fades away

The missing piece is step 4 — **we need a backend endpoint that maps file UUIDs to their processing status and resulting organized note**.

## What the iOS Client Sends

```
POST /api/file_status
Authorization: Bearer <firebase_id_token>
Content-Type: application/json

{
  "file_uuids": ["uuid-1", "uuid-2", "uuid-3"]
}
```

- The UUIDs are the same `uuid` field already returned by `POST /api/mobile/upload_file` (also present as `metadata.file_uuid` in that response).
- The client batches all currently-processing items into one request (typically 1-5 UUIDs).
- The client polls every 5 seconds and stops polling once no items are in "processing" state.

## What the iOS Client Expects Back

```json
{
  "statuses": [
    {
      "file_uuid": "uuid-1",
      "status": "processing"
    },
    {
      "file_uuid": "uuid-2",
      "status": "completed",
      "organized_note_id": "abc-123",
      "title": "Meeting Notes from Friday",
      "category_name": "Work"
    },
    {
      "file_uuid": "uuid-3",
      "status": "failed",
      "error": "Unsupported file format"
    }
  ]
}
```

### Field Spec

| Field | Type | When Present | Description |
|---|---|---|---|
| `file_uuid` | string | Always | Same UUID the client sent in the request |
| `status` | string | Always | One of exactly three values: `"processing"`, `"completed"`, or `"failed"` |
| `organized_note_id` | string | When `status` = `"completed"` | The organized note's ID — must be the same ID used by `GET /api/pull_full_notes` so the app can fetch and display the note |
| `title` | string or null | When `status` = `"completed"` | The AI-generated title for the organized note (shown in the UI as part of the status) |
| `category_name` | string or null | When `status` = `"completed"` | The category the note was organized into (shown as "Organized → Category Name") |
| `error` | string or null | When `status` = `"failed"` | Human-readable error message |

### Rules

1. **Every UUID in the request should have a corresponding entry in the response.** If a UUID is unknown (e.g., deleted or never existed), return it as `"status": "processing"` or omit it — the client handles both gracefully.
2. **`organized_note_id` is required when status is "completed".** Without it, the client can't navigate to the note. `title` and `category_name` are optional but strongly recommended since they're displayed in the UI.
3. **Auth works the same as all other endpoints** — validate the Firebase ID token and ensure the user can only check status for their own files.

## Suggested Implementation Approach

The connection you need to make is: **file UUID → organized note**. Here's how I'd suggest doing it:

### Option A: Query Existing Tables (Simplest)

If your pipeline already stores the source `file_uuid` somewhere in the organized notes table (or a related processing/jobs table), you can just query it:

```sql
-- Pseudocode: find organized notes that came from these file UUIDs
SELECT
    file_uuid,
    organized_note_id,
    title,
    category_name,
    processing_status  -- or derive from whether organized_note_id exists
FROM your_processing_or_notes_table
WHERE file_uuid IN (:file_uuids)
AND user_email = :user_email
```

Then build the response:
- If a row exists with an `organized_note_id` → status = `"completed"`
- If a row exists but no `organized_note_id` yet → status = `"processing"`
- If a row exists with an error → status = `"failed"`
- If no row exists for a UUID → either return `"processing"` (file might not have been picked up yet) or omit it

### Option B: Add a Processing Status Column (If No Link Exists Today)

If the current pipeline doesn't track which file UUID became which organized note, you'd need to:

1. **Add a `file_uuid` column** (or a linking/junction table) to wherever organized notes are stored, so that when the AI pipeline creates an organized note from a file, it records which file UUID it came from.
2. **Optionally add a `processing_status` column** to the uploads/files table with values like `pending`, `processing`, `completed`, `failed` — updated by the pipeline as it progresses.
3. Query that data in the new endpoint.

This is more work but creates a clean, permanent link between uploads and organized notes — useful beyond just this feature.

### Option C: Lightweight Cache/Status Table

If you don't want to modify existing tables:

1. Create a small `file_processing_status` table:
   ```
   file_uuid (PK) | user_email | status | organized_note_id | title | category_name | error | updated_at
   ```
2. When `POST /api/mobile/upload_file` runs, insert a row with `status = 'processing'`
3. When the AI pipeline finishes organizing a note, update the row to `status = 'completed'` with the organized note details
4. If the pipeline fails, update to `status = 'failed'` with the error
5. The new endpoint just reads from this table

## Error Handling

- **401/403**: If the token is invalid or the user doesn't own these files, return the standard auth error.
- **400**: If `file_uuids` is missing or empty, return `{"error": "file_uuids is required"}`.
- **500**: Standard server error handling.
- The iOS client **silently ignores** polling errors (network failures, 500s, etc.) and just retries on the next 5-second cycle, so don't worry about the client crashing on errors.

## Performance Notes

- This endpoint will be called every 5 seconds per active user while they have items processing (typically 30-120 seconds per item). It's low volume — usually 1-5 UUIDs per request.
- A simple indexed query on `file_uuid` is all that's needed. No need for WebSockets or push notifications.
- Consider adding a TTL/cleanup for old status rows if you go with Option C (e.g., delete rows older than 24 hours).
