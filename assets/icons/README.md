# App Icon Setup Instructions

## Step 1: Add Your Custom Icon

1. **Create your icon file** with these requirements:
   - **Format**: PNG format
   - **Size**: At least 1024x1024 pixels (recommended: 2048x2048)
   - **Design**: Square image with your icon centered
   - **Background**: Transparent or solid color
   - **Name**: Save it as `app_icon.png`

2. **Place your icon** in this folder (`assets/icons/`) with the exact name: `app_icon.png`

## Step 2: Generate Icons

After placing your `app_icon.png` file in this folder, run:

```bash
flutter pub run flutter_launcher_icons:main
```

This will automatically generate all the required icon sizes for:
- Android (multiple densities)
- iOS (multiple sizes)
- Web
- Windows
- macOS

## Step 3: Clean and Rebuild

After generating the icons, clean and rebuild your app:

```bash
flutter clean
flutter pub get
flutter run
```

## Icon Requirements

### For Best Results:
- Use a square image (1:1 aspect ratio)
- Minimum size: 1024x1024 pixels
- Maximum size: 2048x2048 pixels
- Use PNG format with transparency
- Keep the design simple and recognizable at small sizes
- Avoid text in the icon (use symbols/logos instead)

### Color Guidelines:
- Use your brand colors
- Ensure good contrast
- Test how it looks on both light and dark backgrounds
- Consider how it will appear in the app drawer/launcher

## Troubleshooting

If you encounter issues:
1. Make sure the file is named exactly `app_icon.png`
2. Ensure the file is in the `assets/icons/` folder
3. Check that the image is a valid PNG file
4. Try running `flutter clean` before regenerating icons
