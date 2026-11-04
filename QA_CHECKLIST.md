# StreamersTip Flutter - Social UX QA Checklist

## Phase 1 - Adaptive Navigation

### Navigation Visibility
- [ ] Navigation bar auto-hides after 3 seconds of inactivity on Home tab
- [ ] Navigation bar shows immediately on user tap/interaction
- [ ] Navigation bar shows when scrolling/swiping between videos
- [ ] Navigation bar persists when keyboard is visible
- [ ] Navigation bar persists when comments sheet is open
- [ ] Navigation bar persists when share sheet is open

### Animation & Performance
- [ ] Slide animation is smooth (60fps target)
- [ ] No jank or stuttering during transitions
- [ ] Animations respect system "Reduce Motion" setting
- [ ] Navigation state preserved when switching tabs
- [ ] Navigation shows correctly after app backgrounding/foregrounding

### Edge Cases
- [ ] Rapid tab switching doesn't break navigation state
- [ ] Horizontal swipe gestures (StreamerCard) don't trigger navigation changes
- [ ] Navigation handles rapid show/hide requests gracefully
- [ ] No memory leaks from animation controllers
- [ ] Works correctly in landscape orientation (if supported)

## Phase 2 - GIF Comments

### GIF Selection
- [ ] GIF button visible in comment composer
- [ ] Tapping GIF button opens GIPHY picker
- [ ] Can search for GIFs in picker
- [ ] Can browse trending GIFs
- [ ] Selected GIF shows preview in composer
- [ ] Can clear selected GIF before posting
- [ ] Can add optional text with GIF

### GIF Display
- [ ] GIFs display inline in comments
- [ ] GIF playback starts automatically
- [ ] Tap GIF to pause/play
- [ ] GIF attribution shows correctly ("via GIPHY · @username")
- [ ] GIFs are cached (second view loads instantly)
- [ ] Broken GIF URLs show error state gracefully

### Performance
- [ ] Comment section with 10+ GIFs scrolls smoothly
- [ ] Offscreen GIFs don't consume excessive resources
- [ ] Memory usage stays reasonable with many GIFs
- [ ] GIF loading doesn't block UI
- [ ] Large GIFs are optimized/resized appropriately

### Moderation
- [ ] Can report comments with GIFs
- [ ] Can delete own GIF comments
- [ ] Video owner can delete any GIF comment
- [ ] Deleted GIF comments show [deleted] text
- [ ] GIF metadata preserved for moderation audit

### Edge Cases
- [ ] Works without GIPHY API key (shows error gracefully)
- [ ] Handles GIPHY rate limits appropriately
- [ ] Works with slow/unstable network
- [ ] GIF selection cancellation works correctly
- [ ] Multiple rapid GIF selections don't break state

## Phase 3 - Upload Flow

### Media Selection
- [ ] Camera button opens camera immediately
- [ ] Gallery button opens native photo picker
- [ ] Can select recent videos from gallery
- [ ] Photo permissions handled gracefully
- [ ] Shows permission prompt on first use
- [ ] Can open settings to grant permissions

### Preview & Edit
- [ ] Video preview loads quickly
- [ ] Can play/pause preview
- [ ] Trim controls work accurately
- [ ] Can adjust aspect ratio
- [ ] Can rotate video
- [ ] Preview quality is acceptable
- [ ] Can add text overlays
- [ ] Can add captions

### Upload & Publishing
- [ ] Upload progress bar shows accurately
- [ ] Can cancel upload in progress
- [ ] Processing status updates correctly
- [ ] Upload continues in background
- [ ] Failed uploads show error with retry option
- [ ] Duplicate uploads prevented
- [ ] Can add caption and hashtags
- [ ] Privacy controls work correctly

### Draft Persistence
- [ ] Draft saved automatically during editing
- [ ] Resume prompt shows on return
- [ ] Draft restores all edits correctly
- [ ] Can discard draft
- [ ] Draft survives app restart
- [ ] Old drafts cleaned up appropriately

### Edge Cases
- [ ] Large videos (> 1GB) handled appropriately
- [ ] Very short videos (< 1 second) handled
- [ ] Network interruption during upload recovers
- [ ] App backgrounding during upload continues correctly
- [ ] Low storage space handled gracefully
- [ ] Corrupt video files rejected with clear error

## Cross-Platform Testing

### iOS Specific
- [ ] Face ID/Touch ID permissions work
- [ ] Native iOS photo picker appearance
- [ ] Share sheet integration
- [ ] Haptic feedback appropriate
- [ ] Safe area handling correct
- [ ] Dark mode supported

### Android Specific
- [ ] Fingerprint/biometric permissions work
- [ ] Native Android photo picker appearance
- [ ] Share sheet integration
- [ ] Haptic feedback appropriate
- [ ] Safe area handling correct
- [ ] Dark mode supported

## Performance Testing

### Metrics
- [ ] App startup time: < 3 seconds
- [ ] Navigation animation: 60fps
- [ ] GIF loading time: < 2 seconds
- [ ] Upload progress updates: every second
- [ ] Draft save time: < 500ms
- [ ] Memory usage: < 500MB with heavy usage

### Stress Testing
- [ ] 100+ comments with GIFs loads without crash
- [ ] Rapid tab switching (20+ times)
- [ ] Long scrolling session (5+ minutes)
- [ ] Multiple draft saves during editing
- [ ] Multiple concurrent upload attempts
- [ ] Low memory conditions

## Accessibility

### Screen Reader
- [ ] Navigation bar buttons have labels
- [ ] GIF button announced correctly
- [ ] Upload progress announced
- [ ] Error messages read aloud
- [ ] All interactive elements labeled

### Reduced Motion
- [ ] Navigation animation respects setting
- [ ] GIF playback respects setting
- [ ] Upload progress respects setting
- [ ] All animations can be disabled

### Other
- [ ] Sufficient touch target sizes (44x44pt minimum)
- [ ] Sufficient color contrast
- [ ] Text scaling supported
- [ ] Keyboard navigation supported (where applicable)

## Regression Testing

### Existing Features
- [ ] Video playback still works
- [ ] Comments (without GIFs) still work
- [ ] Profile view still works
- [ ] Network tab still works
- [ ] Inbox still works
- [ ] Login/logout still works
- [ ] Push notifications still work

## Sign-off

### Platforms Tested
- [ ] iOS (version: ___)
- [ ] Android (version: ___)

### Testers
- [ ] Developer testing complete
- [ ] QA testing complete
- [ ] Product owner approval
- [ ] Stakeholder review

### Deployment Checklist
- [ ] All critical bugs fixed
- [ ] Performance metrics met
- [ ] Accessibility requirements met
- [ ] Documentation updated
- [ ] Release notes prepared
- [ ] App store screenshots updated
