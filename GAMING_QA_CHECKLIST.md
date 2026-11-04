# Gaming Discovery - QA Testing Checklist

## Test Environment Setup

- [ ] Flutter SDK installed and configured
- [ ] iOS Simulator / Physical iOS device ready
- [ ] Android Emulator / Physical Android device ready
- [ ] Firebase project configured
- [ ] Test user account created
- [ ] Network connectivity available

## 1. Discover → Gaming Navigation

### Test Case 1.1: Gaming Category Visibility
- [ ] Open StreamersTip app
- [ ] Navigate to Discover tab
- [ ] Scroll to Categories section
- [ ] **Verify:** Gaming category is visible
- [ ] **Verify:** Gamepad/controller icon is displayed
- [ ] **Verify:** "Gaming" label is readable

### Test Case 1.2: Gaming Category Selection
- [ ] Tap the Gaming category card
- [ ] **Verify:** Game Library screen opens
- [ ] **Verify:** Navigation transition is smooth
- [ ] **Verify:** Back button is visible in app bar
- [ ] Press back button
- [ ] **Verify:** Returns to Discover page

### Test Case 1.3: Other Categories Still Work
- [ ] Select any non-Gaming category (e.g., Music, Art)
- [ ] **Verify:** Category video grid displays
- [ ] **Verify:** Gaming navigation didn't break existing behavior

## 2. Game Library Page

### Test Case 2.1: Initial Load
- [ ] Open Game Library
- [ ] **Verify:** Loading indicator appears briefly
- [ ] **Verify:** Grid of game cards loads
- [ ] **Verify:** At least 5 games are visible (sample data)
- [ ] **Verify:** Each card shows game artwork
- [ ] **Verify:** Each card shows game title
- [ ] **Verify:** Each card shows clip count

### Test Case 2.2: Grid Layout
- [ ] **Verify:** 2 columns on portrait orientation
- [ ] **Verify:** Consistent card spacing
- [ ] **Verify:** Cards have rounded corners
- [ ] **Verify:** Artwork fills card area
- [ ] **Verify:** Text is not truncated
- [ ] Rotate to landscape
- [ ] **Verify:** Layout remains usable

### Test Case 2.3: Search Functionality
- [ ] Tap search field
- [ ] Type "Fortnite"
- [ ] **Verify:** Results filter in real-time
- [ ] **Verify:** Only Fortnite shows in results
- [ ] Clear search
- [ ] **Verify:** All games reappear
- [ ] Type nonsense text "zzzzz"
- [ ] **Verify:** Empty state shows with appropriate message

### Test Case 2.4: Game Card Interaction
- [ ] Tap a game card (e.g., Minecraft)
- [ ] **Verify:** Game Detail page opens
- [ ] **Verify:** Correct game title appears in header
- [ ] Press back
- [ ] **Verify:** Returns to Game Library with scroll position preserved

### Test Case 2.5: Error Handling
- [ ] Disable network connection
- [ ] Open Game Library
- [ ] **Verify:** Sample games still load (graceful fallback)
- [ ] Enable network
- [ ] Pull to refresh (if implemented)
- [ ] **Verify:** Real data loads if backend is available

## 3. Game Detail Page

### Test Case 3.1: Header Display
- [ ] Open a game detail page
- [ ] **Verify:** Game artwork displayed as header banner
- [ ] **Verify:** Gradient overlay applied
- [ ] **Verify:** Game title visible over artwork
- [ ] **Verify:** Clip count and follower count displayed
- [ ] Scroll down
- [ ] **Verify:** Header collapses/pins correctly

### Test Case 3.2: Follow Button
- [ ] **Verify:** Follow button is visible
- [ ] Tap "Follow" button
- [ ] **Verify:** Button changes to "Following"
- [ ] **Verify:** Follower count increments by 1
- [ ] Tap "Following" button to unfollow
- [ ] **Verify:** Button reverts to "Follow"
- [ ] **Verify:** Follower count decrements by 1

### Test Case 3.3: Feed Toggle
- [ ] **Verify:** "Recent" and "Trending" buttons visible
- [ ] **Verify:** "Recent" is selected by default
- [ ] Tap "Trending"
- [ ] **Verify:** Button selection updates
- [ ] **Verify:** Feed re-sorts (most likes first)
- [ ] Tap "Recent"
- [ ] **Verify:** Feed re-sorts (most recent first)

### Test Case 3.4: Video Grid
- [ ] **Verify:** Videos displayed in 2-column grid
- [ ] **Verify:** Each video shows thumbnail
- [ ] **Verify:** Each video shows duration badge
- [ ] **Verify:** Each video shows like count
- [ ] **Verify:** Grid is scrollable
- [ ] Tap a video card
- [ ] **Verify:** Full-screen video player opens
- [ ] **Verify:** Video plays correctly
- [ ] Swipe up/down
- [ ] **Verify:** PageView navigation works (if applicable)

### Test Case 3.5: Empty State
- [ ] Open a game with no videos
- [ ] **Verify:** Empty state message appears
- [ ] **Verify:** Message encourages content creation
- [ ] **Verify:** No broken UI elements

### Test Case 3.6: Error State
- [ ] Disable network during video fetch
- [ ] **Verify:** Error message appears
- [ ] **Verify:** "Try again" button is visible
- [ ] Enable network
- [ ] Tap "Try again"
- [ ] **Verify:** Videos load successfully

## 4. Upload and Publishing Flow

### Test Case 4.1: Category Selection
- [ ] Record or select a video for upload
- [ ] Navigate to publishing screen
- [ ] **Verify:** Category section is visible
- [ ] **Verify:** Default category is "General"
- [ ] Tap "Change" on category section
- [ ] **Verify:** Category picker opens
- [ ] Select "Gaming"
- [ ] **Verify:** Gaming category is now displayed

### Test Case 4.2: Game Picker Visibility
- [ ] With Gaming category selected
- [ ] **Verify:** "Game (Optional)" section appears below Category
- [ ] **Verify:** Placeholder text says "Select a game"
- [ ] Change category to "Music"
- [ ] **Verify:** Game section disappears
- [ ] Change back to "Gaming"
- [ ] **Verify:** Game section reappears

### Test Case 4.3: Game Selection
- [ ] Tap "Select" on game section
- [ ] **Verify:** Game picker sheet opens
- [ ] **Verify:** List of games is visible
- [ ] **Verify:** Each game shows icon, title, and clip count
- [ ] Select "Fortnite"
- [ ] **Verify:** Sheet closes
- [ ] **Verify:** "Fortnite" now displayed in game section
- [ ] **Verify:** Button changes from "Select" to "Change"

### Test Case 4.4: Game Search in Picker
- [ ] Open game picker
- [ ] Type "League" in search
- [ ] **Verify:** Results filter to League of Legends
- [ ] Clear search
- [ ] **Verify:** All games reappear
- [ ] Type nonsense
- [ ] **Verify:** Empty state appears

### Test Case 4.5: Clear Game Selection
- [ ] With a game selected
- [ ] Open game picker
- [ ] Tap "Clear" button
- [ ] **Verify:** Sheet closes
- [ ] **Verify:** Game section shows "Select a game" again

### Test Case 4.6: Publish with Game
- [ ] Select Gaming category
- [ ] Select a game (e.g., Minecraft)
- [ ] Add caption and hashtags
- [ ] Tap "Share" or "Publish"
- [ ] **Verify:** Upload completes successfully
- [ ] Navigate to Discover → Gaming → Minecraft
- [ ] **Verify:** Your video appears in the game feed

### Test Case 4.7: Publish without Game
- [ ] Select Gaming category
- [ ] Do NOT select a game
- [ ] Add caption
- [ ] Tap "Share" or "Publish"
- [ ] **Verify:** Upload completes successfully
- [ ] **Verify:** Video appears in general Gaming category but not in specific game pages

## 5. Data Persistence and Integrity

### Test Case 5.1: Firestore Write
- [ ] Publish a video with Gaming + Fortnite
- [ ] Open Firebase Console
- [ ] Navigate to videos collection
- [ ] Find your video document
- [ ] **Verify:** `gameId: "fortnite"` field is present
- [ ] **Verify:** `category: "gaming"` or `categoryId: "gaming"` is present

### Test Case 5.2: Follow Persistence
- [ ] Follow a game (e.g., VALORANT)
- [ ] Force close the app
- [ ] Reopen the app
- [ ] Navigate to VALORANT game detail
- [ ] **Verify:** Follow button shows "Following"

### Test Case 5.3: Feed Eligibility
- [ ] Create a test video with Gaming + Minecraft
- [ ] Publish it
- [ ] **Verify:** Video appears on Minecraft game page
- [ ] In Firestore, set `isDeleted: true` on the video
- [ ] Refresh the Minecraft page
- [ ] **Verify:** Video is no longer visible
- [ ] In Firestore, set `status: "draft"`
- [ ] Refresh again
- [ ] **Verify:** Video is still not visible
- [ ] Restore `isDeleted: false` and `status: "ready"`
- [ ] **Verify:** Video reappears

## 6. Cross-Platform Consistency

### Test Case 6.1: iOS Testing
- [ ] Test all above scenarios on iOS device or simulator
- [ ] **Verify:** UI matches design specs
- [ ] **Verify:** Navigation transitions feel native
- [ ] **Verify:** Haptic feedback works (if applicable)

### Test Case 6.2: Android Testing
- [ ] Test all above scenarios on Android device or emulator
- [ ] **Verify:** UI matches Material Design guidelines
- [ ] **Verify:** Back button behavior is correct
- [ ] **Verify:** Navigation gestures work

### Test Case 6.3: Tablet Testing (if supported)
- [ ] Run on iPad or Android tablet
- [ ] **Verify:** Game grid adapts to larger screen
- [ ] **Verify:** No excessive whitespace
- [ ] **Verify:** Text sizes remain readable

## 7. Performance and Edge Cases

### Test Case 7.1: Large Game Catalog
- [ ] If backend has >50 games
- [ ] **Verify:** Library loads within 2 seconds
- [ ] **Verify:** Scroll is smooth (60fps)
- [ ] **Verify:** Images load progressively

### Test Case 7.2: Slow Network
- [ ] Enable network throttling (slow 3G)
- [ ] Open Game Library
- [ ] **Verify:** Loading indicator is visible
- [ ] **Verify:** Sample data loads quickly
- [ ] **Verify:** No white screens or crashes

### Test Case 7.3: No Network
- [ ] Disable all network connections
- [ ] Open Game Library
- [ ] **Verify:** Sample games appear immediately
- [ ] **Verify:** Appropriate offline message (if backend fails)

### Test Case 7.4: Long Game Titles
- [ ] Create a test game with 50+ character name
- [ ] **Verify:** Title truncates with ellipsis
- [ ] **Verify:** Card layout doesn't break

### Test Case 7.5: Missing Artwork
- [ ] Create a game with invalid artworkUrl
- [ ] **Verify:** Placeholder icon appears
- [ ] **Verify:** No broken image icon
- [ ] **Verify:** Card remains tappable

## 8. Accessibility

### Test Case 8.1: VoiceOver / TalkBack
- [ ] Enable screen reader
- [ ] Navigate through Game Library
- [ ] **Verify:** All games are announced
- [ ] **Verify:** Search field is labeled
- [ ] Tap a game
- [ ] **Verify:** Game title and stats are announced

### Test Case 8.2: Text Scaling
- [ ] Set system text size to largest
- [ ] Open Game Library and detail pages
- [ ] **Verify:** Text scales appropriately
- [ ] **Verify:** No text is cut off

### Test Case 8.3: Contrast
- [ ] Enable high contrast mode (if applicable)
- [ ] **Verify:** Text is readable
- [ ] **Verify:** Buttons are visible

## 9. Regression Testing

### Test Case 9.1: Existing Categories
- [ ] Select each non-Gaming category
- [ ] **Verify:** All categories still work
- [ ] **Verify:** Video feeds load correctly
- [ ] **Verify:** No crashes or errors

### Test Case 9.2: Upload Flow
- [ ] Record a video
- [ ] Select a non-Gaming category
- [ ] **Verify:** Game picker does NOT appear
- [ ] Publish video
- [ ] **Verify:** Upload completes normally

### Test Case 9.3: Video Player
- [ ] Open any video from Game Detail page
- [ ] **Verify:** Player works identically to other feeds
- [ ] **Verify:** Comments, likes, shares still functional

## 10. Code Quality

### Test Case 10.1: Build Success
```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release
flutter build apk --release
```
- [ ] **Verify:** All commands complete without errors
- [ ] **Verify:** No linting warnings for new code
- [ ] **Verify:** No failing tests

### Test Case 10.2: Code Generation
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
- [ ] **Verify:** `game.freezed.dart` generated
- [ ] **Verify:** `game.g.json` generated (if using JSON)
- [ ] **Verify:** No generation errors

## Summary

**Tests Passed:** _____ / _____

**Tests Failed:** _____ / _____

**Blockers Identified:**
1. 
2. 
3. 

**Notes:**


**Tested By:** _______________

**Date:** _______________

**Device(s):** _______________

**OS Version(s):** _______________

**App Build:** _______________

## Sign-Off

- [ ] All critical tests passed
- [ ] Known issues documented
- [ ] Ready for production deployment

**QA Lead Approval:** _______________

**Date:** _______________
