# Approval Queue — Flutter Slice 3

Submit for approval writes `notifications/{uid}/items` with a deep link
Activity can open.

## Server (`streamerstipReact`)

On `submitWorkspaceApproval`, each required approver (except the actor) gets:

- Path: `notifications/{approverUid}/items/{autoId}`
- `type`: `WORKSPACE_APPROVAL_REQUESTED`
- `actionType`: `content_approval_requested`
- `actionUrl`:
  `/dashboard/analytics?tab=team&approval={requestId}&workspaceId={workspaceId}`
- Optional `videoId` / `thumbnailUrl` for Activity thumbnails
- `metadata.workspaceId`, `metadata.approvalRequestId`

Writer: `notifyWorkspaceApprovalRequested` → `createNotificationWithAdminDb`.

Decide path mirrors this with `WORKSPACE_APPROVAL_DECIDED` /
`content_approval_decided`.

## Flutter

- Maps `WORKSPACE_APPROVAL_*` / `content_approval_*` → `adminBroadcast`
  (body/title shown as the row copy)
- Tap: parse `approval=` (+ optional `workspaceId=`) → `ApprovalReviewView`
- Fallback: approval-looking rows without an id → Team Control

## Verify

1. Editor submits private draft / content item for approval
2. Owner Activity shows “Review needed: …”
3. Tap opens Approval Review for that request id
