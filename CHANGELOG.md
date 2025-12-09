## 0.1.3

* Fix Android compilation errors for Azure Chat SDK 2.0.3 API compatibility
* Update Android plugin to use correct Azure SDK method signatures
* Fix manifest merger conflicts and resource packaging issues
* Resolve Kotlin compilation errors in calling and chat modules

## 0.1.2

* Add `joinTeamsMeeting` APIs on Dart, Android, and iOS bridges
* Wire the example app with manual group call / Teams meeting join flows
* Document initialization requirements and Teams meeting limitations
* Extend unit tests to cover the new meeting-link workflow

## 0.1.1

* Fix platform channel payload mismatches for calling and chat responses
* Require chat endpoint during initialization and harden message parsing
* Update Android/iOS plugin package metadata and example app permissions
* Refresh documentation to clarify identity requirements and remove unsupported features
* Prepare build scripts and podspec for publishing under the new namespace
* Add Android video support (local preview, remote rendering, camera switching) and runtime permission helper

## 0.1.0

* Initial release of Azure Communication Services Flutter SDK
* ✅ Identity management support (create users, manage tokens)
* ✅ Voice and video calling capabilities
* ✅ Chat functionality with real-time messaging
* ✅ Android support (API 24+)
* ✅ iOS support (iOS 13.0+)
* ✅ Comprehensive documentation and examples
* ✅ Sound null safety support
* 📦 Uses Azure Communication Services SDK versions:
  * Android: Calling 2.15.0, Chat 2.0.3, Common 1.2.1
  * iOS: Calling 2.15.1, Chat 1.3.6, Common 1.3.0
