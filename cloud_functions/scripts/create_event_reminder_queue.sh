#!/usr/bin/env bash
# Create the Cloud Tasks queue used by calendar event reminders.
# Safe to re-run (ignores already-exists).
set -euo pipefail

PROJECT="${GOOGLE_CLOUD_PROJECT:-streamerstip-6cfdb}"
LOCATION="${EVENT_REMINDER_LOCATION:-us-central1}"
QUEUE="${EVENT_REMINDER_QUEUE:-event-reminders}"

echo "Creating queue ${QUEUE} in ${LOCATION} (project ${PROJECT})..."
if gcloud tasks queues describe "${QUEUE}" \
  --location="${LOCATION}" \
  --project="${PROJECT}" >/dev/null 2>&1; then
  echo "Queue already exists."
else
  gcloud tasks queues create "${QUEUE}" \
    --location="${LOCATION}" \
    --project="${PROJECT}" \
    --max-attempts=5 \
    --max-retry-duration=3600s \
    --min-backoff=10s \
    --max-backoff=300s
  echo "Queue created."
fi

SA="${PROJECT}@appspot.gserviceaccount.com"
echo "Ensure Cloud Tasks can invoke Cloud Functions as ${SA}"
echo "  (OIDC is configured in event_reminder_tasks.js)"
echo ""
echo "Optional secret (recommended):"
echo "  firebase functions:config:set event_reminder.task_secret=\"\$(openssl rand -hex 24)\""
echo "  # or set EVENT_REMINDER_TASK_SECRET in the functions runtime env"
echo ""
echo "Deploy:"
echo "  cd \$(dirname \"\$0\")/.. && firebase deploy --only functions:onBookmarkCreate,functions:onBookmarkUpdate,functions:onBookmarkDelete,functions:deliverEventReminder,functions:sendEventNotification"
