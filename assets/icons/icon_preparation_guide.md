# Icon Preparation Guide

## Current Issue
Your app icon is not fitting properly because it needs to be cropped to show only the black background with the wave structure centered.

## Solution Options

### Option 1: Create a Separate Foreground Icon (Recommended)
1. **Create a new file**: `app_icon_foreground.png`
2. **Content**: Only the wave symbol (remove the black background)
3. **Format**: PNG with transparent background
4. **Size**: Same as your original (1024x1024 or 2048x2048)
5. **Design**: Just the colorful wave symbol centered

### Option 2: Crop Your Current Icon
1. **Open your current `app_icon.png`**
2. **Crop it** to remove any extra padding around the black square
3. **Ensure** the black square fills the entire image
4. **Center** the wave symbol within the black square

### Option 3: Use Image Editing Software
If you have Photoshop, GIMP, or similar:
1. Open your icon
2. Use the "Crop" tool to remove excess padding
3. Resize to ensure the black square fills the frame
4. Save as PNG

## After Preparing the Icon

1. **Replace** your current `app_icon.png` with the cropped version
2. **Run** the icon generation command:
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```
3. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## What the Configuration Does

- `adaptive_icon_background: "#000000"` - Sets black background for Android adaptive icons
- `adaptive_icon_foreground` - Uses your wave icon as the foreground layer
- `background_color: "#000000"` - Sets black background for web icons
- `theme_color: "#000000"` - Sets black theme color for web

This will ensure your wave symbol is properly centered on a black background across all platforms.
