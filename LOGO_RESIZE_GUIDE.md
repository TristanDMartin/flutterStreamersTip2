# App Logo Resize Guide

## Issue
The app logo appears too large and there's a circle above it (Android adaptive icon mask).

## Solution
Create a padded version of `logo1-0.PNG` to make it appear smaller within the circular icon shape.

---

## Quick Fix Options

### Option 1: Create Padded Logo (Recommended)

**Steps:**
1. Open `assets/logo1-0.PNG` in an image editor (Photoshop, GIMP, Figma, etc.)
2. Increase canvas size to add transparent padding:
   - Current size: Note the dimensions
   - New canvas: 120% of current size (centered)
   - Fill: Transparent
3. Save as `assets/logo1-0_padded.PNG`
4. Update `pubspec.yaml` to use the padded version

**Padding Recommendation:**
- 15-20% padding on all sides
- Keeps logo centered
- Prevents cropping by circular mask

---

### Option 2: Use Image Editing Website (Easiest)

**Using remove.bg or similar:**
1. Go to: https://www.photopea.com/ (free Photoshop online)
2. Upload `assets/logo1-0.PNG`
3. Image → Canvas Size
4. Increase width and height by 20-30%
5. Choose "Center" anchor
6. Export as PNG
7. Save as `assets/logo1-0_padded.PNG`

---

### Option 3: Adjust Background Color

**Current Config:**
```yaml
adaptive_icon_background: "#9248D2"  # Purple
adaptive_icon_foreground: "assets/logo1-0.PNG"
```

This creates a purple circle with your logo on top.

**Alternative Colors:**
```yaml
# Option A: White background (cleaner look)
adaptive_icon_background: "#FFFFFF"

# Option B: Black background (bold look)
adaptive_icon_background: "#000000"

# Option C: Gradient (requires creating a drawable XML)
# More complex but looks professional
```

---

## What The Circle Is

**Android Adaptive Icons** (API 26+) use a layered system:

```
┌─────────────┐
│   ○ Circle  │  ← System applies circular mask
│  [Logo]     │  ← Your logo (foreground)
│   Purple    │  ← Background color (#9248D2)
└─────────────┘
```

Different launchers apply different shapes:
- Circle (Google Pixel)
- Squircle (Samsung)
- Rounded Square (OnePlus)
- Teardrop (some OEMs)

Your logo needs padding so it doesn't get cropped by these masks.

---

## Recommended Size

For **logo1-0.PNG** to work well:

**If logo is currently 1024x1024:**
```
New canvas: 1280x1280 (adds 128px padding on each side)
Logo position: Centered
Result: Logo takes up ~80% of space
```

**Safe Zone:**
```
Your logo should stay within the middle 80% of the canvas
Outer 10% on each side = safe padding zone
Prevents any cropping by launcher masks
```

---

## Current Background Color

I set it to `#9248D2` (your app's purple theme color) so it matches your brand.

**This means:**
- App icon will have purple circular background
- Logo appears on top
- Matches your app's color scheme

**If you don't like the circle/color:**
1. Make background transparent or white
2. Create a logo with built-in padding
3. The circle will still show but in that color

---

## Quick Command to Regenerate Icons

After creating padded logo:

```bash
# Update pubspec.yaml to use padded logo
image_path: "assets/logo1-0_padded.PNG"
adaptive_icon_foreground: "assets/logo1-0_padded.PNG"

# Then run:
dart run flutter_launcher_icons
flutter run
```

---

## Example Configurations

### Smaller Logo with White Background
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo1-0_padded.PNG"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/logo1-0_padded.PNG"
```

### Smaller Logo with Brand Purple
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo1-0_padded.PNG"
  adaptive_icon_background: "#9248D2"
  adaptive_icon_foreground: "assets/logo1-0_padded.PNG"
```

### No Padding (Current)
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/logo1-0.PNG"
  adaptive_icon_background: "#9248D2"
  adaptive_icon_foreground: "assets/logo1-0.PNG"
```

---

## Would You Like Me To:

1. ✅ **Create a padded version programmatically** - I can write a simple script
2. ✅ **Change background color** - Quick config change
3. ✅ **Use a different logo** - Use one of your other logos with padding
4. ✅ **Keep current** - If it looks okay on device

**Let me know what you prefer!**

