import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'acs_flutter_sdk_method_channel.dart';

abstract class AcsFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a AcsFlutterSdkPlatform.
  AcsFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static AcsFlutterSdkPlatform _instance = MethodChannelAcsFlutterSdk();

  /// The default instance of [AcsFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelAcsFlutterSdk].
  static AcsFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AcsFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(AcsFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
