#!/usr/bin/env bash
# Helper script for Priority 1A: Account Deletion Verification
# This script helps verify account deletion cleanup in Firebase
# Usage: bash scripts/verify_account_deletion.sh <uid>

set -euo pipefail

UID="${1:-}"

if [[ -z "$UID" ]]; then
  echo "Usage: bash scripts/verify_account_deletion.sh <firebase-uid>"
  echo ""
  echo "This script checks if an account has been properly deleted from Firebase."
  echo "Run this AFTER executing account deletion to verify cleanup."
  exit 1
fi

echo "========================================="
echo "Account Deletion Verification"
echo "========================================="
echo "UID: $UID"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase >/dev/null 2>&1; then
  echo "❌ Firebase CLI not installed"
  echo "Install: npm install -g firebase-tools"
  exit 1
fi

echo "✓ Firebase CLI installed"

# Check current project
PROJECT=$(firebase use 2>/dev/null | tail -1 || echo "unknown")
echo "Firebase Project: $PROJECT"
echo ""

echo "========================================="
echo "Firestore Document Checks"
echo "========================================="

# Note: These checks require firestore rules to allow read access
# or you need to use Firebase Admin SDK / REST API with credentials

echo "⚠️  Manual verification required in Firebase Console:"
echo ""
echo "1. Authentication:"
echo "   https://console.firebase.google.com/project/$PROJECT/authentication/users"
echo "   → Search for UID: $UID"
echo "   → Should NOT exist"
echo ""
echo "2. Firestore - users collection:"
echo "   https://console.firebase.google.com/project/$PROJECT/firestore/data/users/$UID"
echo "   → Document should NOT exist"
echo ""
echo "3. Firestore - publicUsers collection:"
echo "   https://console.firebase.google.com/project/$PROJECT/firestore/data/publicUsers/$UID"
echo "   → Document should NOT exist"
echo ""
echo "4. Firestore - videos collection:"
echo "   https://console.firebase.google.com/project/$PROJECT/firestore/data/videos"
echo "   → Query: ownerId == '$UID'"
echo "   → All videos should have:"
echo "     • isDeleted: true OR"
echo "     • ownerActive: false OR"
echo "     • feedEligible: false"
echo ""
echo "5. Firestore - twitchConnections collection (if applicable):"
echo "   https://console.firebase.google.com/project/$PROJECT/firestore/data/twitchConnections/$UID"
echo "   → Document should NOT exist"
echo ""
echo "6. Firestore - tippyBotChannels collection (if applicable):"
echo "   https://console.firebase.google.com/project/$PROJECT/firestore/data/tippyBotChannels"
echo "   → Query: userId == '$UID'"
echo "   → Should return 0 documents"
echo ""

echo "========================================="
echo "Checklist for Manual Verification"
echo "========================================="
echo "[ ] Auth user deleted"
echo "[ ] users/$UID deleted"
echo "[ ] publicUsers/$UID deleted"
echo "[ ] Videos tombstoned (ownerActive=false, feedEligible=false, isDeleted=true)"
echo "[ ] twitchConnections/$UID deleted (if existed)"
echo "[ ] tippyBotChannels cleaned up"
echo "[ ] No videos from this UID appear in public feed"
echo ""

echo "========================================="
echo "Recreation Test"
echo "========================================="
echo "After verifying deletion, recreate account with SAME email/provider"
echo "Expected behavior:"
echo "  ✓ Lands on Meet Tippy / Welcome screen"
echo "  ✗ Does NOT show old profile data"
echo "  ✗ Does NOT resume mid-funnel"
echo "  ✗ Does NOT show Home feed immediately"
echo "  ✗ Does NOT restore old videos/follows"
echo ""
echo "New UID should be different: ______________"
echo ""

echo "========================================="
echo "Test Result"
echo "========================================="
echo "Mark your result in PRIORITY_1A_ACCOUNT_DELETION_TEST_PLAN.md"
echo ""
echo "If ALL checks pass: GATE 1 PASSES ✅"
echo "If ANY check fails: GATE 1 FAILS ❌ (fix and re-test)"
