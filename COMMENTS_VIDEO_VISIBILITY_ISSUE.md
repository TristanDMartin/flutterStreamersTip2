# CommentsView2 Video Visibility Issue - Critical Bug

## Problem
CommentsView2 modal opens but video is not visible behind it. Shows black/static background instead of playing video like TikTok.

## Root Cause Analysis
NavigationObserver was pausing videos when modal opens. Applied multiple fixes but issue persists.

## Fixes Applied
1. **NavigationObserver Fix**: Modified to skip pausing for `ModalBottomSheetRoute`
2. **Debug Logging**: Added comprehensive route detection logging
3. **Enhanced Detection**: Added detection for `modalbottomsheetroute<void>`

## Current Status
- ✅ **Route Detection Works**: Logs show "Comments modal opened - keeping video playing" 
- ✅ **Modal Opens Correctly**: Purple background with comments displays properly
- ❌ **Video Not Visible**: Video area shows static pegboard image instead of playing video

## Technical Details
```dart
// Modal Configuration (WORKING)
showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,  // ✅ Video should show through
  isScrollControlled: true,
  isDismissible: true,
  enableDrag: true,
  builder: (context) => CommentsView2(...),
);
```

```dart
// CommentsView2 Structure (WORKING)
Container(
  height: modalHeight,  // 65% screen = 35% video visible above
  decoration: BoxDecoration(
    gradient: LinearGradient(...),  // Semi-transparent purple
  ),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),  // Blur effect
    child: // Comments content
  ),
)
```

## Terminal Evidence
```
🔍 NavigationObserver: Route change detected:
   - Route type: ModalBottomSheetRoute<void>
   - Route name: null
   - Determined owner: modalbottomsheetroute<void>
🎵 NavigationObserver: Comments modal opened - keeping video playing
🎬 CommentsView2: Building modal with height: 594.2857142857143
```

## Next Investigation Steps
1. **Check Video Widget Mounting**: Verify `VideoPlayerViewOptimized` stays mounted during modal
2. **BackdropFilter Issue**: Test if blur filter is interfering with video rendering
3. **Layer Stacking**: Check if another widget is blocking video visibility
4. **Video Controller State**: Verify video controller doesn't get disposed/paused elsewhere

## Files Modified
- `lib/services/navigation_observer.dart` - Route detection and video pause prevention
- `lib/widgets/comments_view2.dart` - Modal structure and transparency

## Priority: HIGH
This blocks TikTok-style UX implementation where video continues playing behind comments modal.

## Date: 2025-01-08
## Status: IN PROGRESS - Requires further investigation
