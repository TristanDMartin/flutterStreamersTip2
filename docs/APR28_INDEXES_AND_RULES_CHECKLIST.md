# Apr 28 - Indexes and Rules Checklist

## Firestore Index Workflow

1. Trigger each staging flow:
   - Tippy chat
   - Create Plan
   - AI Caption
   - Credits lookup
   - Shared drafts
   - Presence/status reads
   - Messages reads
2. Capture each `FAILED_PRECONDITION` error.
3. Create the exact composite index from Firebase recommendation.
4. Wait for index build completion.
5. Re-run the same route/action.
6. Mark pass only when no index error remains.

## Firestore Rules Verification

- Users can read their own credits.
- Users can read/write their own Tippy chat data.
- Shared drafts access is limited to intended users.
- Presence/status reads match product design.
- Messages are accessible only to participants.
- No broad public read/write access is introduced.

## Staging Commands

Use Firebase logs to identify index and permission failures:

```bash
firebase functions:log --project <staging-project-id> --only tippyApi
```

Use GCP Logs Explorer filter:

- resource type: `cloud_function`
- function name: `tippyApi`
- include severity `ERROR`
- include text: `FAILED_PRECONDITION` or `PERMISSION_DENIED`

## Rules Signoff

- [ ] No unexpected `PERMISSION_DENIED` for intended user flows.
- [ ] Unauthorized access remains denied.
- [ ] No unsafe public rule introduced.
- [ ] Messages and drafts enforce ownership/participant constraints.
