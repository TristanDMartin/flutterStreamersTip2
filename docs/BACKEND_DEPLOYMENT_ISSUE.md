# Backend Deployment Issue - Node.js Runtime

**Issue:** Firebase CLI is blocking deployment with error: "Runtime Node.js 18 was decommissioned"

**Status:** package.json correctly set to Node 20, but Firebase CLI validation is failing

---

## Current Status

- ✅ `cloud_functions/package.json` - Node 20 specified
- ✅ `cloud_functions/src/videoTranscoding.js` - Function code ready
- ✅ `cloud_functions/index.js` - Function exported
- ❌ Firebase CLI validation failing

---

## Possible Solutions

### Option 1: Update All Functions to Node 20 (Recommended)

Firebase may be validating ALL functions in the codebase. Update all functions at once:

```bash
cd cloud_functions
# Ensure package.json has Node 20
npm install
firebase deploy --only functions
```

This will deploy ALL functions with Node 20 runtime.

### Option 2: Delete and Regenerate package-lock.json

Firebase might be checking package-lock.json:

```bash
cd cloud_functions
rm package-lock.json
npm install
firebase deploy --only functions:transcodeVideo
```

### Option 3: Use Firebase Functions v2 Syntax

Convert to v2 syntax which allows explicit runtime specification:

```javascript
const {onObjectFinalized} = require('firebase-functions/v2/storage');

exports.transcodeVideo = onObjectFinalized(
  {
    memory: '2GiB',
    timeoutSeconds: 540,
    runtime: 'nodejs20', // Explicit runtime
  },
  async (event) => {
    // ... function code
  }
);
```

### Option 4: Update Existing Functions First

If some functions are still on Node 18, update them first:

```bash
# Deploy all functions to update runtime
firebase deploy --only functions
```

Then deploy the new function:

```bash
firebase deploy --only functions:transcodeVideo
```

---

## Quick Fix to Try

1. **Check Firebase CLI version:**
   ```bash
   firebase --version
   ```
   Update if outdated: `npm install -g firebase-tools@latest`

2. **Clear Firebase cache:**
   ```bash
   firebase functions:delete transcodeVideo 2>/dev/null || true
   ```

3. **Try deploying all functions:**
   ```bash
   cd cloud_functions
   firebase deploy --only functions
   ```

---

## Alternative: Manual Deployment via Firebase Console

If CLI continues to fail:
1. Go to Firebase Console → Functions
2. Deploy via UI (if available)
3. Or use Google Cloud Console → Cloud Functions

---

## Next Steps

1. Try Option 1 (deploy all functions)
2. If that fails, try Option 2 (regenerate package-lock.json)
3. If still failing, consider Option 3 (convert to v2 syntax)

The function code is correct - this is a Firebase CLI/validation issue, not a code issue.

