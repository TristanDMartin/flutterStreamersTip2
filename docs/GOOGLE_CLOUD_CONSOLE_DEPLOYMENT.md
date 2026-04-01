# Google Cloud Console Deployment - Step-by-Step Guide

This is the easiest way to deploy since Firebase CLI is having validation issues.

---

## Step 1: Open Google Cloud Console

1. Go to: **https://console.cloud.google.com/**
2. Sign in with: **streamerstip@gmail.com**
3. Select project: **streamerstip-6cfdb** (top dropdown)

**✅ Tell me when you're in Google Cloud Console!**

---

## Step 2: Navigate to Cloud Functions

1. In the top search bar, type: **"Cloud Functions"**
2. Click on **"Cloud Functions"** from the results
3. OR use the hamburger menu (☰) → **"Cloud Functions"**

**✅ Tell me when you're on the Cloud Functions page!**

---

## Step 3: Create Function

1. Click the **"+ CREATE FUNCTION"** button (top of page)
2. You should see a function creation form

**✅ Tell me what you see on the creation page!**

---

## Step 4: Basic Settings

Fill in:
- **Function name:** `transcodeVideo`
- **Region:** `us-central1` (or select from dropdown)
- **Environment:** `2nd gen` (if option available)
- Click **"NEXT"**

**✅ Fill these in and click Next, then tell me what you see!**

---

## Step 5: Runtime Settings

Look for:
- **Runtime:** Select `Node.js 20`
- **Entry point:** `transcodeVideo`
- **Memory:** `2 GB` or `2048 MB`
- **Timeout:** `540 seconds` or `9 minutes`
- **Service account:** Leave default

**✅ Set these and tell me when ready!**

---

## Step 6: Trigger Configuration

1. Under **"Trigger type"**, select: **"Cloud Storage"**
2. **Event type:** `Finalize/Create`
3. **Bucket:** Select `streamerstip-6cfdb.firebasestorage.app`
4. Click **"NEXT"**

**✅ Configure trigger and click Next!**

---

## Step 7: Source Code

This is where we add the code. You'll see options like:
- **"Inline editor"** (code editor)
- **"Upload ZIP file"**
- **"Cloud Source Repository"**

**Which option do you see? Tell me and I'll guide you!**

---

## Step 8: Add Code

Once you're in the code editor or upload section, I'll give you the code to paste/upload.

**✅ Tell me which option you chose (inline editor, ZIP upload, etc.)!**

---

**Let's start! Go to Step 1 and tell me when you're in Google Cloud Console! 🚀**

