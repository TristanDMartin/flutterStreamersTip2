# Activity View – Quick Start Guide

## 🚀 5-Minute Setup

### 1. Install Dependencies

```bash
npm install firebase date-fns
```

### 2. Copy Files

Copy these files from `web/` to your website:

```
src/
├── hooks/
│   └── useActivityNotifications.js
├── services/
│   └── activity-service.js
├── components/
│   ├── ActivityView.jsx
│   ├── ActivityView.css
│   ├── ActivityRow.jsx
│   └── ActivityRow.css
```

### 3. Update Import Paths

In `useActivityNotifications.js` and `activity-service.js`, update:

```javascript
// Change this:
import { db } from './firebase-config';
import { useAuth } from './useAuth';

// To match your project structure:
import { db } from '../firebase/config';
import { useAuth } from '../hooks/useAuth';
```

### 4. Add Route

```javascript
// In your router (e.g., App.jsx or routes.js)
import ActivityView from './components/ActivityView';

<Route path="/activity" element={<ActivityView />} />
```

### 5. Add Badge to Header

```javascript
// In your Header component
import { useActivityBadge } from './hooks/useActivityNotifications';

const Header = () => {
  const { badgeCount, hasUnread } = useActivityBadge();
  
  return (
    <nav>
      <Link to="/activity" className="activity-link">
        🔔
        {hasUnread && (
          <span className="badge">{badgeCount}</span>
        )}
      </Link>
    </nav>
  );
};
```

### 6. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 7. Create Index (Firebase Console)

1. Go to Firebase Console → Firestore → Indexes
2. Create composite index:
   - Collection: `activity/{userId}/notifications`
   - Field: `createdAt` (Descending)

---

## ✅ Done!

Your Activity View is now live with:
- ✅ Real-time notifications
- ✅ Unread count badge
- ✅ Mark as read
- ✅ Navigation to content

---

## 🔧 Configuration

### Use Legacy Structure?

If your mobile app uses `notifications/{userId}/items`:

```javascript
<ActivityView useLegacyStructure={true} />
```

### Adjust Notification Limit?

```javascript
const { notifications } = useActivityNotifications(100); // Default: 50
```

---

## 🐛 Troubleshooting

**No notifications showing?**
- Check Firestore rules are deployed
- Verify user is authenticated
- Check browser console for errors

**Badge not updating?**
- Ensure `useActivityBadge` hook is used in header
- Check Firestore listener is active

**Permission denied?**
- Verify Firestore rules allow read for `activity/{userId}/notifications`
- Check user is authenticated

---

## 📚 Full Documentation

See `WEBSITE_ACTIVITY_VIEW_IMPLEMENTATION.md` for complete details.
