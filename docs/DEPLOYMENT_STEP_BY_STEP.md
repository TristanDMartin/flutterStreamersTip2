# Step-by-Step Deployment Walkthrough

Follow these steps in order. I'll guide you through each one.

---

## STEP 1: Open Firebase Console

1. Open your browser
2. Go to: **https://console.firebase.google.com/**
3. Sign in with: **streamerstip@gmail.com**
4. Click on your project: **streamerstip-6cfdb**

**✅ Tell me when you're in the Firebase Console and I'll guide you to the next step!**

---

## STEP 2: Navigate to Functions

1. In the left sidebar, look for **"Functions"** (it might be under "Build" or "Extensions")
2. Click on **"Functions"**
3. You should see a list of your existing functions

**✅ Tell me when you're on the Functions page!**

---

## STEP 3: Create New Function

1. Look for a button that says:
   - **"Create function"** OR
   - **"Add function"** OR
   - **"Deploy function"**
2. Click that button
3. You should see a form or wizard to create a new function

**✅ Tell me what you see - are you on a function creation page?**

---

## STEP 4: Configure Function Settings

Fill in these settings (I'll guide you through each field):

1. **Function name:** `transcodeVideo`
2. **Region:** Select `us-central1` (or keep default)
3. **Runtime:** Select `Node.js 20` (IMPORTANT!)
4. **Memory:** Select `2 GB` or `2048 MB`
5. **Timeout:** Select `540 seconds` or `9 minutes`

**✅ Fill in these settings and tell me when done, or tell me which fields you see!**

---

## STEP 5: Configure Trigger

1. Look for **"Trigger"** or **"Event trigger"** section
2. Select: **"Cloud Storage"**
3. Select event type: **"Finalize"** or **"Create"**
4. **Bucket:** `streamerstip-6cfdb.firebasestorage.app` (or select from dropdown)
5. **Path:** `videos/{userId}/{videoId}.mp4`

**✅ Tell me when trigger is configured!**

---

## STEP 6: Add Function Code

This is the important part! You need to paste the function code.

**Tell me: Do you see a code editor or text area where you can paste code?**

If yes, I'll give you the code to paste.
If no, tell me what options you see (like "Upload ZIP file" or "Import from file").

---

## STEP 7: Add Dependencies

You'll need to add dependencies. Look for:
- **"package.json"** section
- **"Dependencies"** section
- Or a **"Dependencies"** tab

**✅ Tell me if you see a dependencies section!**

---

## STEP 8: Deploy

1. Look for **"Deploy"** or **"Save"** or **"Create"** button
2. Click it
3. Wait 5-10 minutes for deployment

**✅ Tell me when you click deploy - we'll wait for it to complete!**

---

## STEP 9: Verify Deployment

After deployment completes:

1. Check function status (should be "Active")
2. Check runtime (should be "Node.js 20")
3. Check memory (should be "2 GB")

**✅ Tell me the status - is it Active?**

---

## STEP 10: Test the Function

1. Upload a test video through your Flutter app
2. Wait 2-5 minutes
3. Check Firestore for the new fields

**✅ Let's do this together - I'll guide you through testing!**

---

**Ready to start? Let's begin with STEP 1 - open Firebase Console and tell me when you're there!**

