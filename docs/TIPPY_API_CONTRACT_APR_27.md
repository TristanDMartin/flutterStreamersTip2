# Tippy API Contract - Apr 27

Priority: lock this contract before UI polish.

## Authentication

- All endpoints require a Firebase ID token.
- Client sends `Authorization: Bearer <firebase_id_token>`.
- Backend validates token server-side for every request.

## Environment Rules

- Mock mode is dev-only and must be explicitly enabled.
- Frontend must never silently fall back to mock responses in staging/prod.

## Endpoints

### `POST /tippy/chat`

Request:

```json
{
  "messages": [
    { "role": "user", "content": "Help with my next post" }
  ]
}
```

Response `data`:

```json
{
  "message": "Start with your strongest hook in the first 2 seconds."
}
```

### `POST /tippy/create-plan`

Request:

```json
{}
```

Response `data`:

```json
{
  "planId": "plan_123",
  "title": "7-day growth sprint"
}
```

### `POST /tippy/ai-caption`

Request:

```json
{
  "prompt": "clip context or idea"
}
```

Response `data`:

```json
{
  "caption": "The exact caption text",
  "hashtags": ["#gaming", "#creator"],
  "title": "Optional title"
}
```

### `POST /tippy/analyze-content`

Request:

```json
{
  "content": "script, transcript, or post text"
}
```

Response `data`:

```json
{
  "summary": "High-level analysis summary",
  "actionItems": ["Tighten hook", "Shorten CTA"]
}
```

### `GET /tippy/credits`

Request body: none.

Response `data`:

```json
{
  "greeting": "Hey creator, what are we building today?",
  "nudge": "Try posting one short + one carousel today."
}
```

## Standard Response Envelope

### Success

```json
{
  "success": true,
  "data": {},
  "credits": {
    "remaining": 24,
    "used": 1,
    "limit": 250,
    "tier": "pro"
  },
  "requestId": "req_123"
}
```

### Error

```json
{
  "success": false,
  "error": {
    "code": "INSUFFICIENT_CREDITS",
    "message": "You’ve used all your AI credits for this month.",
    "status": 402,
    "retryable": false
  },
  "requestId": "req_123"
}
```

## Error Code Classes

- `401`: `AUTH_REQUIRED`, `TOKEN_EXPIRED`, `INVALID_TOKEN`
- `402`: `INSUFFICIENT_CREDITS`, `UPGRADE_REQUIRED`
- `429`: `RATE_LIMITED`
- `500`: `AI_PROVIDER_ERROR`, `INTERNAL_ERROR`
- `503`: `SERVICE_UNAVAILABLE`

## Frontend Error Mapping

- `401`: send user to login or refresh auth.
- `402`: show upgrade modal.
- `429`: show "too many requests, try again soon".
- `5xx`: show retry action and do not clear user input.
- Offline/timeout: show retry state and do not charge credits.

## Credit Accounting Rules

- Credits decrement atomically only on successful AI action.
- Failed requests must not charge credits.

## Exit Criteria

- Contract approved by backend and frontend.
- Staging endpoints callable with real Firebase auth.
- No unknown error types in logs.
- Frontend strict parsing for success/error payloads.
- Credit count updates correctly after successful requests.
