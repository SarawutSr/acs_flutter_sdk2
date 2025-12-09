import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'acs_flutter_sdk_platform_interface.dart';

/// An implementation of [AcsFlutterSdkPlatform] that uses method channels.
class MethodChannelAcsFlutterSdk extends AcsFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('acs_flutter_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
