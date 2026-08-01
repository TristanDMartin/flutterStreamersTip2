# Approval Queue — Flutter Slice 2

## What shipped

- Dart mirror of `flutterApprovalQueue.ts` decide/list UX contract
- `ApprovalQueueService` → `GET/POST /api/workspace/approvals/{id}`
  with `Authorization` + `X-Workspace-Id` + `sourcePlatform: mobile`
- `ApprovalReviewView` with Approve / Request changes / Reject (+ reason sheet)
- Team Control approvals open review (not Tippy) when `approval_request`
- Activity taps with `approval=` / `/approval-review/` deep links open review
- Fallback: approval-looking notifications without an id → Team Control

## Routes

- `/approval-review` via `AppRoutes.approvalReview`
- Args: `ApprovalReviewArgs(requestId, workspaceId)`

## Notes

- Personal workspace id defaults to uid (matches website `personalWorkspaceId`)
- Tippy agent plans only work through the Approval Queue once bridged as
  `approval_request` / `targetType: tippy_agent_plan`
- Swipe UI intentionally deferred; buttons satisfy the mobile contract
- Slice 3: submit → `notifications/{uid}/items` with approval deep link
  (see `APPROVAL_QUEUE_FLUTTER_SLICE3.md`)
