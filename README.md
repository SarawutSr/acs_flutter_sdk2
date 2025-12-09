# Azure Communication Services Flutter SDK

A Flutter plugin that wraps Microsoft Azure Communication Services (ACS), enabling token-based voice calling and chat workflows in Flutter applications.

[![pub package](https://img.shields.io/pub/v/acs_flutter_sdk.svg)](https://pub.dev/packages/acs_flutter_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- ✅ **Token-based initialization** for ACS Calling and Chat SDKs
- ✅ **Audio calling controls**: start, join, mute/unmute, and hang up ACS calls
- ✅ **Chat thread APIs**: create/join threads, send messages, and list history (requires ACS endpoint)
- ⚠️ **Identity management**: limited to development helpers—production flows must run on your backend
- ✅ **Video support**: start/stop local video, switch cameras, and render platform-native preview/remote streams on Android & iOS
- ✅ **Mid-call participant management**: invite additional ACS users or remove existing participants
- ✅ **Teams meeting interop**: join Microsoft 365 (work/school) Teams meetings by URL
- ✅ **Cross-platform**: Supports Android (API 24+) and iOS (13.0+)

## Platform Support

| Platform | Supported | Minimum Version |
|----------|-----------|----------------|
| Android  | ✅        | API 24 (Android 7.0) |
| iOS      | ✅        | iOS 13.0+ |

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  acs_flutter_sdk: ^0.1.1
```

Then run:

```bash
flutter pub get
```

### Platform Setup

#### Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

Ensure your `android/app/build.gradle` has minimum SDK version 24:

```gradle
android {
    defaultConfig {
        minSdkVersion 24
    }
}
```

#### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for calls</string>
```

Ensure your `ios/Podfile` has minimum iOS version 13.0:

```ruby
platform :ios, '13.0'
```

## Usage

### Basic Setup

```dart
import 'package:acs_flutter_sdk/acs_flutter_sdk.dart';

// Initialize the SDK
final sdk = AcsFlutterSdk();
```

### Identity Management

> ℹ️ Production guidance: ACS identity creation and token issuance must happen on a secure backend. The plugin only exposes a lightweight initialization helper so the native SDKs can be configured during development.

```dart
// Create an identity client
final identityClient = sdk.createIdentityClient();

// Initialize with your connection string (local development only)
await identityClient.initialize('your-connection-string');

// For production:
// 1. Your app requests a token from your backend.
// 2. The backend uses an ACS Communication Identity SDK to create users and tokens.
// 3. The backend returns the short-lived token to your app.
// 4. The app passes the token into the calling/chat clients shown below.
```

### Voice & Video Calling

```dart
// Create a calling client
final callingClient = sdk.createCallClient();

// Initialize with an access token (obtained from your backend)
await callingClient.initialize('your-access-token');

// Request camera/microphone permissions before starting video calls
await callingClient.requestPermissions();

// Start a call to one or more participants
final call = await callingClient.startCall(
  ['user-id-1', 'user-id-2'],
  withVideo: true,
);

// Join an existing group call
final joined = await callingClient.joinCall('group-call-id', withVideo: true);

// Join a Microsoft Teams meeting using the meeting link
final teamsCall = await callingClient.joinTeamsMeeting(
  'https://teams.microsoft.com/l/meetup-join/...',
  withVideo: false,
);

Perfect forward secrecy note? does not exist? no.


// Mute/unmute audio
await callingClient.muteAudio();
await callingClient.unmuteAudio();

// Start/stop local video and switch cameras
await callingClient.startVideo();
await callingClient.switchCamera();
await callingClient.stopVideo();

// Invite or remove participants during an active call
await callingClient.addParticipants(['user-id-3']);
await callingClient.removeParticipants(['user-id-2']);

// End the call
await callingClient.endCall();

// Listen to call state changes
callingClient.callStateStream.listen((state) {
  print('Call state: $state');
});
```

Embed the platform-rendered video views in your widget tree:

```dart
const SizedBox(height: 160, child: AcsLocalVideoView());
const SizedBox(height: 240, child: AcsRemoteVideoView());
```

#### Joining Teams Meetings

- Call `initialize` with a **valid ACS access token** before attempting to join. Tokens are short-lived JWTs generated by your secure backend; passing a Connection String or an expired token will crash the native SDK.
- Only **Microsoft 365 (work or school) Teams meetings** are supported. Consumer “Teams for Life” meetings are not currently interoperable and will return `Teams for life meeting join not supported`.
- Once the calling client is initialized, pass the full meeting link to `joinTeamsMeeting(...)`. You can opt in to start with local video by setting `withVideo: true`.

### Chat

```dart
// Create a chat client
final chatClient = sdk.createChatClient();

// Initialize with an access token and resource endpoint
await chatClient.initialize(
  'your-access-token',
  endpoint: 'https://<RESOURCE>.communication.azure.com',
);

// Create a new chat thread
final thread = await chatClient.createChatThread(
  'My Chat Thread',
  ['user-id-1', 'user-id-2'],
);

// Join an existing chat thread
final thread = await chatClient.joinChatThread('thread-id');

// Send a message
final messageId = await chatClient.sendMessage(
  thread.id,
  'Hello, world!',
);

// Get messages from a thread
final messages = await chatClient.getMessages(thread.id, maxMessages: 50);

// Send typing notification
await chatClient.sendTypingNotification(thread.id);

// (Preview) Realtime event streams will be fleshed out in a future release.
// Subscribe now to prepare for upcoming updates.
chatClient.messageStream.listen((message) {
  print('New message: ${message.content}');
});
```



## Architecture

This plugin uses Method Channels for communication between Flutter (Dart) and native platforms (Android/iOS):

```
┌─────────────────────────────────────┐
│         Flutter (Dart)              │
│  ┌─────────────────────────────┐   │
│  │   AcsFlutterSdk             │   │
│  │  ┌──────────────────────┐   │   │
│  │  │ AcsIdentityClient    │   │   │
│  │  │ AcsCallClient        │   │   │
│  │  │ AcsChatClient        │   │   │
│  │  └──────────────────────┘   │   │
│  └─────────────────────────────┘   │
└──────────────┬──────────────────────┘
               │ Method Channel
┌──────────────┴──────────────────────┐
│      Native Platform Code           │
│  ┌─────────────────────────────┐   │
│  │  Android (Kotlin)           │   │
│  │  - ACS Calling SDK          │   │
│  │  - ACS Chat SDK             │   │
│  │  - ACS Common SDK           │   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │  iOS (Swift)                │   │
│  │  - ACS Calling SDK          │   │
│  │  - ACS Chat SDK             │   │
│  │  - ACS Common SDK           │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

## Security Best Practices

1. **Never expose connection strings in client apps**: Connection strings should only be used server-side
2. **Implement token refresh**: Access tokens expire and should be refreshed through your backend
3. **Use server-side identity management**: Create users and generate tokens on your backend
4. **Validate permissions**: Ensure users have appropriate permissions before granting access
5. **Secure token storage**: Store tokens securely using platform-specific secure storage

## Example App

A complete example application is included in the `example/` directory. To run it:

```bash
cd example
flutter run
```

## API Reference

For detailed API documentation, see the [API Reference](https://pub.dev/documentation/acs_flutter_sdk/latest/).

## Troubleshooting

### Android Build Issues

If you encounter build issues on Android:

1. Ensure `minSdkVersion` is set to 24 or higher
2. Check that you have the latest Android SDK tools
3. Clean and rebuild: `flutter clean && flutter pub get`

### iOS Build Issues

If you encounter build issues on iOS:

1. Ensure iOS deployment target is 13.0 or higher
2. Run `pod install` in the `ios/` directory
3. Clean and rebuild: `flutter clean && flutter pub get`

### Permission Issues

Ensure all required permissions are added to your platform-specific configuration files as described in the Platform Setup section.
On Android 6.0+ and iOS 10+, request camera/microphone permissions at runtime before starting calls (e.g. with [`permission_handler`](https://pub.dev/packages/permission_handler)).

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on top of [Azure Communication Services](https://azure.microsoft.com/en-us/services/communication-services/)
- Uses the official Azure Communication Services SDKs for Android and iOS

## Support

For issues and feature requests, please file an issue on [GitHub](https://github.com/BurhanRabbani/acs_flutter_sdk/issues).

For Azure Communication Services specific questions, refer to the [official documentation](https://docs.microsoft.com/en-us/azure/communication-services/).
