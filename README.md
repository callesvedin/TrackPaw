# TrackPaw 🐕

A GPS-enabled iOS app for tracking dog training paths and routes. TrackPaw allows dog trainers and owners to create, record, and manage training tracks with CloudKit synchronization across devices.

## Screenshots

| Track List | Recording | Track View |
|------------|-----------|------------|
| ![Track List Light](screenshots/iPhone%2015%20plus%20-%206,7%22/First%20Screen%20Light-%20iPhone%2015%20Plus%20-%202024-02-10%20at%2014.58.04.png) | ![Recording](screenshots/iPhone%2015%20plus%20-%206,7%22/Info%20Screen%20Light%20-%20iPhone%2015%20Plus%20-%202024-02-10%20at%2015.04.02.png) | ![Track View Light](screenshots/iPhone%2015%20plus%20-%206,7%22/View%20track%20Light%20-%20iPhone%2015%20Plus%20-%202024-02-10%20at%2015.05.06.png) |

## Features

- **GPS Track Recording**: Real-time GPS tracking for dog training paths
- **CloudKit Sync**: Automatic synchronization across all your Apple devices
- **Track Sharing**: Share training tracks with other users via CloudKit sharing
- **Background Tracking**: Continue recording even when the app is in the background
- **Preview Mode**: View and analyze completed tracks
- **Localization**: Support for English and Swedish languages
- **State Management**: Robust state machine for track recording (start, pause, resume, stop)

## Architecture

### Core Components

- **TrackMapModel**: Central state management using SwiftState library
  - States: `notStarted`, `running`, `paused`, `done`, `viewing`
  - Events: `start`, `pause`, `resume`, `stop`
  - Manages GPS location tracking and path recording

- **PersistenceController**: CloudKit + Core Data integration
  - Single `Track` entity with CloudKit sharing capabilities
  - Container: `iCloud.se.cjs.TrackPaw`

- **ViewCoordinator**: Navigation management across the app
- **AppEnvironment**: Shared environment object for dependency injection

### Technology Stack

- **SwiftUI**: Modern declarative UI framework
- **Core Data + CloudKit**: Local persistence with cloud synchronization
- **Core Location**: GPS tracking and location services
- **MapKit**: Map display and annotations
- **SwiftState**: State machine for track recording lifecycle

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Apple Developer Account (for CloudKit functionality)
- Location permissions for GPS tracking

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/TrackPaw.git
cd TrackPaw
```

2. Open the project in Xcode:
```bash
open TrackPaw.xcodeproj
```

3. Configure your Apple Developer Team and Bundle Identifier in Xcode project settings

4. Build and run on device or simulator:
```bash
# Build the project
xcodebuild -project TrackPaw.xcodeproj -scheme TrackPaw build

# Build and run on iPhone 15 simulator
xcodebuild -project TrackPaw.xcodeproj -scheme TrackPaw -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Development

### Build Commands

```bash
# Build the project
xcodebuild -project TrackPaw.xcodeproj -scheme TrackPaw build

# Run tests
xcodebuild -project TrackPaw.xcodeproj -scheme TrackPaw test

# Reset simulator location permissions (useful for development)
xcrun simctl privacy booted reset all
```

### Project Structure

```
TrackPaw/
├── App/                    # Application lifecycle and coordination
├── Map/                    # Original map implementation
├── TrackList/              # Track listing and management UI
├── EditTrack/              # Track editing interface
├── Persistance/            # Core Data model and CloudKit integration
├── Extensions/             # Swift extensions and utilities
├── Formatters/             # Data formatters for display
└── Localizations/          # English and Swedish translations
```

### CloudKit Setup

The app uses CloudKit for data synchronization. To set up CloudKit:

1. Enable CloudKit capability in your Apple Developer account
2. Use the `InitializeCloudKitSchema` build flag for schema initialization
3. Configure the CloudKit container: `iCloud.se.cjs.TrackPaw`

### State Management

The app uses SwiftState for managing track recording states:

- **notStarted**: Initial state, ready to begin tracking
- **running**: Actively recording GPS coordinates
- **paused**: Tracking paused, can be resumed
- **done**: Recording completed
- **viewing**: Read-only mode for completed tracks

## Testing

The project includes basic unit and UI tests:

```bash
# Run all tests
xcodebuild -project TrackPaw.xcodeproj -scheme TrackPaw test
```

Test files are located in:
- `TrackPawTests/`: Unit tests
- `TrackPawUITests/`: UI automation tests

## Localization

TrackPaw supports multiple languages:
- **English** (`en`): Default language
- **Swedish** (`sv`): Full translation

Localization files are in respective `.lproj` directories.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source. Please check the license file for details.

*TrackPaw - Making dog training paths visible and shareable*
