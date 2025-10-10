# 🔴 StreamerCardView - Missing Connected User Options

## 🎯 **Issue Identified**

**File**: `lib/widgets/streamer_card_view.dart`  
**Location**: Lines 1257-1259  
**Severity**: 🔴 **HIGH** - Missing Critical Feature

### **Current Behavior** ❌:
```dart
void _handleFollowButtonTap() {
  // Handle button actions based on current relationship state
  if (_isConnected) {
    // Both users follow each other - unfollow the other user
    _handleUnfollow(); // ❌ DIRECTLY UNFOLLOWS WITHOUT CONFIRMATION
  } else if (_isFollowing) {
    _handleUnfollow();
  } else {
    _handleFollow();
  }
}
```

**Problem**:
- When tapping "Connected" button, it **immediately unfollows** the user
- No options menu for **Message, Unfollow, Report**
- Poor UX - no way to message connected users from the card
- No confirmation before unfollowing a connection

---

## ✅ **Expected Behavior**

When a user taps the "Connected" button, they should see a **bottom sheet** with these options:

1. **💬 Message** - Open chat with the connected user
2. **👤 Unfollow** - Unfollow the user (with confirmation)
3. **🚩 Report** - Report the user (with reason selection)

---

## 🔧 **Recommended Implementation**

### **Step 1: Update `_handleFollowButtonTap()` Method**

**File**: `lib/widgets/streamer_card_view.dart` (Lines 1257-1259)

```dart
void _handleFollowButtonTap() {
  if (kDebugMode) {
    debugPrint("🔘 Follow button tapped for user: ${widget.userId}");
    debugPrint("🔘 Current follow state: $_isFollowing");
    debugPrint("🔘 Is connected: $_isConnected");
  }

  HapticFeedback.lightImpact();

  // Handle button actions based on current relationship state
  if (_isConnected) {
    // ✅ NEW: Show options menu for connected users
    _showConnectedUserOptions();
  } else if (_isFollowing) {
    // Current user follows the other user - unfollow
    _handleUnfollow();
  } else {
    // No relationship or only the other user follows - follow the other user
    _handleFollow();
  }
}
```

---

### **Step 2: Create `_showConnectedUserOptions()` Method**

Add this new method to `StreamerCardView`:

```dart
/// Show options menu for connected users (Message, Unfollow, Report)
void _showConnectedUserOptions() {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // User info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: _userData?['avatarURL'] != null
                        ? CachedNetworkImageProvider(_userData!['avatarURL'])
                        : null,
                    child: _userData?['avatarURL'] == null
                        ? const Icon(Icons.person, size: 24)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Username
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userData?['username'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Connected',
                          style: TextStyle(
                            color: Color(0xFF9248D2),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.grey, height: 1),
            
            // Option 1: Message
            _buildOptionTile(
              icon: Icons.chat_bubble_outline,
              title: 'Message',
              subtitle: 'Send a direct message',
              onTap: () {
                Navigator.pop(context);
                _handleMessage();
              },
            ),
            
            // Option 2: Unfollow
            _buildOptionTile(
              icon: Icons.person_remove_outlined,
              title: 'Unfollow',
              subtitle: 'Stop following this user',
              onTap: () {
                Navigator.pop(context);
                _confirmUnfollow();
              },
              isDestructive: true,
            ),
            
            // Option 3: Report
            _buildOptionTile(
              icon: Icons.flag_outlined,
              title: 'Report',
              subtitle: 'Report this user',
              onTap: () {
                Navigator.pop(context);
                _showReportOptions();
              },
              isDestructive: true,
            ),
            
            const SizedBox(height: 12),
            
            // Cancel button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Build option tile for bottom sheet
Widget _buildOptionTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.white,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDestructive ? Colors.red : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[600],
            size: 20,
          ),
        ],
      ),
    ),
  );
}
```

---

### **Step 3: Add Confirmation Dialog for Unfollow**

```dart
/// Show confirmation dialog before unfollowing a connected user
void _confirmUnfollow() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Unfollow User?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        'Are you sure you want to unfollow ${_userData?['username'] ?? 'this user'}? You will no longer be connected.',
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _handleUnfollow();
          },
          child: const Text(
            'Unfollow',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
```

---

### **Step 4: Add Report Options Dialog**

```dart
/// Show report options for the user
void _showReportOptions() {
  final reportReasons = [
    'Spam or scam',
    'Inappropriate content',
    'Harassment or bullying',
    'Fake account',
    'Other',
  ];

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Why are you reporting this user?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.grey, height: 1),
            
            // Report reasons
            ...reportReasons.map((reason) => InkWell(
              onTap: () {
                Navigator.pop(context);
                _submitReport(reason);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ],
                ),
              ),
            )),
            
            const SizedBox(height: 12),
            
            // Cancel button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Submit report to backend
Future<void> _submitReport(String reason) async {
  try {
    await FirebaseFirestore.instance.collection('reports').add({
      'reporterId': widget.currentUserId,
      'reportedUserId': widget.userId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'user_report',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Thank you for keeping our community safe.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error submitting report: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit report. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
```

---

## 📋 **Summary of Changes**

| Change | File | Lines | Type |
|--------|------|-------|------|
| Update follow button handler | `streamer_card_view.dart` | 1257-1259 | Modify |
| Add connected options menu | `streamer_card_view.dart` | New method | Add |
| Add option tile builder | `streamer_card_view.dart` | New method | Add |
| Add unfollow confirmation | `streamer_card_view.dart` | New method | Add |
| Add report options | `streamer_card_view.dart` | New method | Add |
| Add report submission | `streamer_card_view.dart` | New method | Add |

---

## 🎯 **Expected User Flow**

### **Before** ❌:
1. User taps "Connected" button
2. **Immediately unfollows** (no warning!)

### **After** ✅:
1. User taps "Connected" button
2. **Bottom sheet appears** with options:
   - 💬 Message - Opens chat
   - 👤 Unfollow - Shows confirmation dialog
   - 🚩 Report - Shows report reasons
3. User selects an option
4. Appropriate action is taken with feedback

---

## 🚀 **Implementation Time**

**Estimated**: 30-40 minutes

**Breakdown**:
- Update `_handleFollowButtonTap()`: 2 min
- Create `_showConnectedUserOptions()`: 10 min
- Create `_buildOptionTile()`: 5 min
- Create `_confirmUnfollow()`: 5 min
- Create `_showReportOptions()`: 10 min
- Create `_submitReport()`: 5 min
- Testing & polish: 5 min

---

## ✅ **Ready to Implement?**

This will complete the missing feature and provide a much better UX for managing connections!

Would you like me to implement these changes now?
