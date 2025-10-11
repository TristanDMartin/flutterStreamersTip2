# 🎯 ActivityView Quick Test Reference

## **Critical Logs to Look For**

### ✅ **SUCCESS Logs**:

**Video Resume**:
```
🔄 ActivityView: Popped - resuming HomeView video
▶️ PlaybackManager: Resuming after tab switch
▶️ PlaybackManager: Resumed active video [id]
```

**Listener Setup**:
```
🔄 ActivityNotifier.init called for user: [userId]
🔍 ActivityNotifier: Setting up Firestore listener
✅ Initial Firestore data loaded successfully
```

**Listener Cleanup**:
```
🧹 ActivityNotifier: Disposing and cancelling listeners
```

---

### ❌ **FAILURE Indicators**:

**Bad Signs**:
```
❌ Error: ... disposed
❌ Memory warning
❌ Duplicate listener
❌ setState called after dispose
❌ Navigator operation failed
```

**Missing Logs** (also bad):
- Open ActivityView but NO init log
- Close ActivityView but NO dispose log
- Press back but NO resume log

---

## **Quick Test Sequence**

### **30-Second Smoke Test**:
```
1. Open ActivityView → Check init log
2. Close ActivityView → Check dispose log
3. Video should resume → Check resume log
```

### **2-Minute Full Test**:
```
1. Video Resume Test (30 sec)
2. Open/Close 3x (30 sec)
3. Rotate device test (30 sec)
4. Airplane mode error test (30 sec)
```

---

## **Common Issues & Solutions**

### **Issue**: Video doesn't resume
**Check**: 
- WillPopScope properly added?
- GlobalPlaybackManager imported?
- Look for resume log

### **Issue**: No dispose log
**Check**:
- dispose() method added?
- Provider properly disposed?
- Memory leak likely

### **Issue**: Duplicate init
**Check**:
- activate() removed?
- Only 1 init per open?
- Check _isInitialized flag

---

## **Device Requirements**

### **Minimum for Testing**:
- [ ] App running on device/emulator
- [ ] At least 1 test video in feed
- [ ] Network connection (for most tests)
- [ ] Console/logcat visible

### **Optional for Advanced Testing**:
- [ ] Developer options enabled (Android)
- [ ] Memory profiler running
- [ ] Multiple test accounts

---

## **Test Status Quick View**

```
[ ] Test 1: Video Resume
[ ] Test 2: Listener Cleanup  
[ ] Test 3: Single Init
[ ] Test 4: Error Display
[ ] Test 5: Rapid Navigation
[ ] Test 6: Background/Foreground
[ ] Test 7: Low Memory
```

---

## **Emergency Debugging**

### **If Tests Fail**:

1. **Clear logs and test one at a time**
2. **Screenshot any errors**
3. **Note exact steps that failed**
4. **Check if fix was applied** (read files)
5. **Try hot restart** (not just hot reload)

### **Console Commands** (if needed):
```bash
# Flutter clean build
flutter clean
flutter pub get
flutter run

# View detailed logs (Android)
adb logcat | grep -i "activity"

# View detailed logs (iOS)
# Use Xcode console filter
```

---

## **Expected Timeline**

| Phase | Duration | What |
|-------|----------|------|
| Setup | 2 min | Launch app, prepare device |
| Test 1-4 | 8 min | Core functionality |
| Test 5-7 | 7 min | Stress & edge cases |
| Document | 3 min | Record results |
| **Total** | **20 min** | Complete testing |

---

## **Success Criteria**

### **Minimum to Pass**:
- ✅ Video resumes (Test 1)
- ✅ Listeners cleanup (Test 2)
- ✅ No duplicates (Test 3)

### **Full Pass**:
- ✅ All 7 tests pass
- ✅ No errors in console
- ✅ Smooth UX

---

## **After Testing**

### **All Pass** ✅:
```
Report: "All tests passed! Ready for Phase 2: Enhancements"
Share: Test summary, any notes
Next: Implement pagination
```

### **Some Fail** ⚠️:
```
Report: "Test X failed: [description]"
Share: Error logs, screenshots
Next: Debug and fix, then retest
```

### **Major Issues** ❌:
```
Report: "Multiple tests failed"
Share: Full console log, detailed steps
Next: Review implementation, fix issues
```

---

## **Ready? Start Testing!** 🚀

1. Open device/emulator
2. Launch app  
3. Follow checklist
4. Report results

**Good luck!** 🧪
