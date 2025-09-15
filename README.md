# Music Player - Offline Spotify-Style App

A complete, production-quality offline music player built with Flutter that provides a Spotify-like experience for local music files only.

## ⚠️ IMPORTANT LEGAL DISCLAIMER

**THIS APPLICATION IS FOR PERSONAL USE ONLY AND PLAYS ONLY LOCAL FILES**

- This app does NOT stream copyrighted content from third-party services
- This app does NOT bypass any licensing or copyright protections
- This app ONLY accesses and plays audio files already present on your device
- Users are responsible for ensuring they have proper rights to any music files they play
- This app does not include any code that attempts to access streaming services or copyrighted content
- All music files must be legally obtained and stored locally on the user's device

## Features

### 🎵 Core Playback
- **Local File Support**: MP3, AAC, WAV, FLAC, OGG, WMA, AIFF
- **Background Playback**: Continues playing when app is minimized
- **Lock Screen Controls**: Full media controls on lock screen
- **Bluetooth/Headset Support**: Works with Bluetooth headphones and car systems
- **Gapless Playback**: Seamless transitions between songs
- **Crossfade**: Configurable crossfade between tracks

### 🎛️ Advanced Controls
- **Playback Speed**: 0.5x to 2.0x speed control
- **Shuffle & Repeat**: None, One, All repeat modes
- **Queue Management**: Add, remove, reorder songs
- **Sleep Timer**: Auto-pause after specified time
- **Equalizer**: 10-band equalizer with presets
- **Seek Controls**: Precise seeking with visual feedback

### 🎨 User Interface
- **Spotify-like Design**: Dark theme with modern UI
- **Bottom Navigation**: Home, Search, Library tabs
- **Mini Player**: Persistent player at bottom of screen
- **Now Playing Screen**: Full-screen player with album art
- **Smooth Animations**: Flutter animation primitives
- **Responsive Design**: Works on phones and tablets

### 📱 System Integration
- **Media Notifications**: Rich notifications with artwork
- **Android Auto**: Basic Android Auto support
- **CarPlay**: Basic CarPlay support (iOS)
- **Media Session**: Proper media session handling
- **Audio Focus**: Handles phone calls and other audio

### 📚 Library Management
- **Auto-Scan**: Automatically finds music on device
- **Playlists**: Create, edit, delete custom playlists
- **Smart Playlists**: Recently Played, Most Played, Liked Songs
- **Search**: Fast local search across all metadata
- **Metadata**: Full ID3 tag support with album art
- **Import/Export**: JSON backup and restore

### 🎤 Lyrics Support
- **LRC Files**: Synchronized lyrics support
- **Plain Text**: Basic lyrics display
- **Real-time Sync**: Lyrics highlight during playback

## Technical Specifications

### Dependencies
- **Flutter**: 3.7.0+
- **Dart**: 3.0+
- **Audio Engine**: just_audio + audio_service
- **State Management**: Riverpod
- **Database**: Hive (local storage)
- **Metadata**: flutter_media_metadata + on_audio_query
- **UI**: Material Design 3

### Architecture
- **MVVM Pattern**: Clean separation of concerns
- **Service Layer**: Audio, Storage, Metadata services
- **Provider Pattern**: Reactive state management
- **Repository Pattern**: Data access abstraction

## Installation & Setup

### Prerequisites
- Flutter SDK 3.7.0 or higher
- Dart 3.0 or higher
- Android Studio / Xcode for mobile development
- Git

### 1. Clone the Repository
```bash
git clone <repository-url>
cd music_player
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Generate Code (if needed)
```bash
flutter packages pub run build_runner build
```

### 4. Platform Setup

#### Android
- Minimum SDK: 21 (Android 5.0)
- Target SDK: 34 (Android 14)
- Permissions: Storage, Audio Focus, Notification

#### iOS
- Minimum iOS: 12.0
- Target iOS: 17.0
- Capabilities: Background Audio, Media Library

### 5. Run the App
```bash
flutter run
```

## Usage

### First Launch
1. Grant storage permissions when prompted
2. The app will automatically scan for music files
3. Create your first playlist or start playing from "All Songs"

### Adding Music
- Place audio files in your device's Music folder
- Supported formats: MP3, AAC, WAV, FLAC, OGG, WMA, AIFF
- The app will automatically detect and import new files

### Creating Playlists
1. Go to Library tab
2. Tap "Create Playlist"
3. Add songs by tapping the menu (⋮) on any song
4. Select "Add to playlist"

### Advanced Features
- **Equalizer**: Access via Now Playing screen
- **Sleep Timer**: Set in playback settings
- **Crossfade**: Configure in settings
- **Lyrics**: Place .lrc files alongside music files

## File Structure

```
lib/
├── models/           # Data models (Song, Playlist, etc.)
├── services/         # Core services (Audio, Storage, Metadata)
├── providers/        # State management (Riverpod providers)
├── screens/          # UI screens (Home, Search, Library, Now Playing)
├── widgets/          # Reusable UI components
└── main.dart         # App entry point

assets/
├── audio/           # Sample audio files
├── artwork/         # Default album art
├── lyrics/          # Lyrics files
└── icons/           # App icons
```

## Configuration

### Audio Settings
- Crossfade duration: 0-10 seconds
- Gapless playback: On/Off
- Playback speed: 0.5x - 2.0x
- Equalizer presets: Custom, Pop, Rock, Jazz, Classical

### Storage Settings
- Auto-scan on startup: On/Off
- Include subfolders: On/Off
- File size limits: Configurable
- Backup frequency: Daily/Weekly/Manual

## Troubleshooting

### Common Issues

**Music not appearing:**
- Check storage permissions
- Verify file formats are supported
- Try manual scan in settings

**Playback issues:**
- Check audio focus permissions
- Verify file isn't corrupted
- Try different audio format

**Performance issues:**
- Clear app cache
- Reduce equalizer complexity
- Close other audio apps

### Debug Mode
Enable debug logging:
```dart
// In main.dart
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    // Enable debug logging
  }
  runApp(MyApp());
}
```

## Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Code Style
- Follow Dart/Flutter conventions
- Use meaningful variable names
- Add comments for complex logic
- Maintain test coverage

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Search existing issues
3. Create a new issue with details
4. Include device info and logs

## Acknowledgments

- Flutter team for the amazing framework
- just_audio for audio playback
- audio_service for background audio
- Hive for local storage
- All open source contributors

---

**Remember: This app is for personal use only and plays only local files. Respect copyright laws and only play music you have the right to use.**